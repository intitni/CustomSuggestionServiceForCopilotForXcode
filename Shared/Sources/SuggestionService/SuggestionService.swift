import CopilotForXcodeKit
import Foundation
import Shared

public final class SuggestionService: SuggestionServiceType {
    public init() {}

    public var configuration: SuggestionServiceConfiguration {
        .init(acceptsRelevantCodeSnippets: true)
    }

    public func notifyAccepted(_ suggestion: CodeSuggestion, workspace: WorkspaceInfo) async {}

    public func notifyRejected(_ suggestions: [CodeSuggestion], workspace: WorkspaceInfo) async {}

    public func cancelRequest(workspace: WorkspaceInfo) async {}

    public func getSuggestions(
        _ request: SuggestionRequest,
        workspace: WorkspaceInfo
    ) async throws -> [CodeSuggestion] {
        try await CodeCompletionLogger.$logger.withValue(.init(request: request)) {
            let lines = request.content.breakLines()
            let (previousLines, nextLines, prefix) = split(
                code: request.content,
                lines: lines,
                at: request.cursorPosition
            )
            let strategy = DefaultRequestStrategy(
                sourceRequest: request,
                prefix: previousLines,
                suffix: nextLines
            )
            let service = CodeCompletionService()
            let suggestedCodeSnippets = try await service.getCompletions(
                strategy.createRequest(),
                model: getModel(),
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
    }
    
    func getModel() -> ChatModel {
        let id = UserDefaults.shared.value(for: \.chatModelId)
        let models = UserDefaults.shared.value(for: \.chatModels)
        return models.first { $0.id == id } ?? UserDefaults.shared.value(for: \.customChatModel)
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

    init(sourceRequest: SuggestionRequest, prefix: [String], suffix: [String])
    func createRequest() -> Request
}

struct DefaultRequestStrategy: RequestStrategy {
    var sourceRequest: SuggestionRequest
    var prefix: [String]
    var suffix: [String]

    struct Request: PreprocessedSuggestionRequest {
        let systemPrompt: String = """
        You are a code completion AI designed to take the surrounding code and \
        references from the codebase into account in order to predict and suggest \
        high-quality code to complete the code enclosed in \(Tag.openingCode) tags.
        You only respond with code that works and fits seamlessly with surrounding code.
        Do not include anything else beyond the code.
        """
        var sourceRequest: SuggestionRequest
        var prefix: [String]
        var suffix: [String]
        var filePath: String { sourceRequest.fileURL.path }
        var relevantCodeSnippets: [RelevantCodeSnippet] { sourceRequest.relevantCodeSnippets }

        func createSourcePrompt(truncatedPrefix: [String], truncatedSuffix: [String]) -> String {
            let promptLinesCount = min(10, max(truncatedPrefix.count, 2))
            let prefixLines = truncatedPrefix.prefix(truncatedPrefix.count - promptLinesCount)
            let promptLines: [String] = {
                let proposed = truncatedPrefix.suffix(promptLinesCount)
                if let last = proposed.last,
                   last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    return Array(proposed) + [
                        """
                        // write some code
                        \(last)
                        """,
                    ]
                }
                return Array(proposed)
            }()

            return """
            Below is the code from file \(filePath) that you are trying to complete.
            Review the code carefully, detect the functionality, formats, style, patterns, \
            and logics in use and use them to predict the completion.
            Make sure your completion has the correct syntax and formatting.
            Enclose the completion the XML tag \(Tag.openingCode).
            Do not duplicate existing implementations.
            Start with a line break if needed.
            Do not put the response in a markdown code block.
            
            Indentation: \
            \(sourceRequest.indentSize) \(sourceRequest.usesTabsForIndentation ? "tab" : "space")

            Here is the code: 
            ```
            \(prefixLines.joined())\(Tag.openingCode)\(Tag.closingCode)\(truncatedSuffix.joined())
            ```
            
            Please complete the code inside \(Tag.openingCode):
            
            \(Tag.openingCode)
            \(promptLines.joined())
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
            sourceRequest: sourceRequest,
            prefix: prefix,
            suffix: suffix
        )
    }
}

