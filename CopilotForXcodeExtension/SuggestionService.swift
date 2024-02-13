import CopilotForXcodeKit
import Foundation
import Shared

final class SuggestionService: SuggestionServiceType {
    var configuration: SuggestionServiceConfiguration {
        .init(acceptsRelevantCodeSnippets: true)
    }

    func notifyAccepted(_ suggestion: CodeSuggestion, workspace: WorkspaceInfo) async {}

    func notifyRejected(_ suggestions: [CodeSuggestion], workspace: WorkspaceInfo) async {}

    func cancelRequest(workspace: WorkspaceInfo) async {}

    func getSuggestions(
        _ request: SuggestionRequest,
        workspace: WorkspaceInfo
    ) async throws -> [CodeSuggestion] {
        let lines = request.content.breakLines()
        let (previousLines, nextLines, prefix) = split(
            code: request.content,
            lines: lines,
            at: request.cursorPosition
        )
        let strategy = DefaultRequestStrategy(
            filePath: request.fileURL.path,
            prefix: previousLines,
            suffix: nextLines,
            relevantCodeSnippets: request.relevantCodeSnippets
        )
        let service = CodeCompletionService()
        let suggestedCodeSnippets = try await service.getCompletions(
            strategy.createRequest(),
            model: UserDefaults.shared.value(for: \.customChatModel),
            count: 1
        )

        return suggestedCodeSnippets
            .filter { !$0.allSatisfy { $0.isWhitespace || $0.isNewline } }
            .map {
                .init(
                    id: UUID().uuidString,
                    text: prefix + $0,
                    position: request.cursorPosition,
                    range: .init(
                        start: .init(
                            line: request.cursorPosition.line,
                            character: 0
                        ),
                        end: request.cursorPosition
                    )
                )
            }
    }

    func split(
        code: String,
        lines: [String],
        at cursorPosition: CursorPosition
    ) -> (head: [String], tail: [String], prefix: String) {
        if code.isEmpty { return ([], [], "") }
        if lines.isEmpty { return ([], [], "") }
        if cursorPosition.line < 0 { return ([], lines, "") }
        if cursorPosition.line >= lines.endIndex { return (lines, [], "") }

        let (previousLines, nextLines, prefix): ([String], [String], String) = {
            let previousLines = Array(lines[0..<cursorPosition.line])
            let nextLines = cursorPosition.line + 1 >= lines.endIndex
                ? []
                : Array(lines[(cursorPosition.line + 1)...])
            let splitLine = lines[cursorPosition.line]
            if cursorPosition.character < 0 {
                return (previousLines, [splitLine] + nextLines, "")
            }
            if cursorPosition.character >= splitLine.count {
                return (previousLines + [splitLine], nextLines, splitLine)
            }
            let firstHalf = String(splitLine[..<splitLine.index(
                splitLine.startIndex,
                offsetBy: cursorPosition.character
            )])
            let secondHalf = String(splitLine[splitLine.index(
                splitLine.startIndex,
                offsetBy: cursorPosition.character
            )...])
            return (previousLines + [firstHalf], [secondHalf] + nextLines, firstHalf)
        }()

        return (previousLines, nextLines, prefix)
    }
}

protocol RequestStrategy {
    associatedtype Request: PreprocessedSuggestionRequest

    func createRequest() -> Request
}

struct DefaultRequestStrategy: RequestStrategy {
    var filePath: String
    var prefix: [String]
    var suffix: [String]
    var relevantCodeSnippets: [RelevantCodeSnippet]

    struct Request: PreprocessedSuggestionRequest {
        let systemPrompt: String = """
        You are a code completion AI designed to take the surrounding code and \
        references from the codebase into account in order to predict and suggest \
        high-quality code to complete the code enclosed in \(Tag.openingCode) tags.
        You only respond with code that works and fits seamlessly with surrounding code.
        Do not include anything else beyond the code.
        """
        var filePath: String
        var prefix: [String]
        var suffix: [String]
        var relevantCodeSnippets: [RelevantCodeSnippet]

        func createSourcePrompt(truncatedPrefix: [String], truncatedSuffix: [String]) -> String {
            let promptLinesCount = min(truncatedPrefix.count, 2)
            let prefixLines = truncatedPrefix.prefix(truncatedPrefix.count - promptLinesCount)
            let promptLines: [String] = {
                let proposed = truncatedPrefix.suffix(promptLinesCount)
                if let last = proposed.last,
                   last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return Array(proposed) + [
                        """
                        // write some code
                        
                        """
                    ]
                }
                return Array(proposed)
            }()

            return """
            Below is the code from file \(filePath) that you are trying to complete.
            Review the code carefully, detect the functionality, formats, style, patterns, \
            and logics in use and use them to predict the completion.
            Enclose the completion the XML tag \(Tag.openingCode).
            Do not duplicate existing implementations.

            Here is the code: ```
            \(prefixLines.joined())\(Tag.openingCode)\(Tag.closingCode)\(truncatedSuffix.joined())
            ```

            Keep writing:
            \(Tag.openingCode)\(promptLines.joined())
            """
        }

        func createSnippetsPrompt(includedSnippets: [RelevantCodeSnippet]) -> String {
            var content = "References from codebase: \n\n"
            for snippet in includedSnippets {
                content += """
                \(Tag.openingSnippet)
                \(snippet.content)
                \(Tag.closingSnippet)
                """ + "\n\n"
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func createRequest() -> Request {
        Request(
            filePath: filePath,
            prefix: prefix,
            suffix: suffix,
            relevantCodeSnippets: relevantCodeSnippets
        )
    }
}

public extension String {
    /// The line ending of the string.
    ///
    /// We are pretty safe to just check the last character here, in most case, a line ending
    /// will be in the end of the string.
    ///
    /// For other situations, we can assume that they are "\n".
    var lineEnding: Character {
        if let last, last.isNewline { return last }
        return "\n"
    }

    func splitByNewLine(
        omittingEmptySubsequences: Bool = true,
        fast: Bool = true
    ) -> [Substring] {
        if fast {
            let lineEndingInText = lineEnding
            return split(
                separator: lineEndingInText,
                omittingEmptySubsequences: omittingEmptySubsequences
            )
        }
        return split(
            omittingEmptySubsequences: omittingEmptySubsequences,
            whereSeparator: \.isNewline
        )
    }

    /// Break a string into lines.
    func breakLines(
        proposedLineEnding: String? = nil,
        appendLineBreakToLastLine: Bool = false
    ) -> [String] {
        let lineEndingInText = lineEnding
        let lineEnding = proposedLineEnding ?? String(lineEndingInText)
        // Split on character for better performance.
        let lines = split(separator: lineEndingInText, omittingEmptySubsequences: false)
        var all = [String]()
        for (index, line) in lines.enumerated() {
            if !appendLineBreakToLastLine, index == lines.endIndex - 1 {
                all.append(String(line))
            } else {
                all.append(String(line) + lineEnding)
            }
        }
        return all
    }
}

