import CopilotForXcodeKit
import Foundation
import Shared

/// This strategy tries to fool the AI model that it has generated a part of the response but fail
/// to complete because of token limit. The strategy will append a user message "Continue" to let
/// the model continue it's (mock) response, so that the format may be more stable.
struct ContinueRequestStrategy: RequestStrategy {
    var sourceRequest: SuggestionRequest
    var prefix: [String]
    var suffix: [String]

    func createPrompt() -> Prompt {
        Prompt(
            sourceRequest: sourceRequest,
            prefix: prefix,
            suffix: suffix
        )
    }

    enum Tag {
        public static let openingCode = "<Code3721>"
        public static let closingCode = "</Code3721>"
        public static let openingSnippet = "<Snippet9981>"
        public static let closingSnippet = "</Snippet9981>"
    }

    struct Prompt: PromptStrategy {
        let systemPrompt: String = """
        You are a senior Swift programer who take the surrounding code and \
        references from the codebase into account in order to write high-quality code to \
        complete the code enclosed in \(Tag.openingCode) tags. \
        You only respond with code that works and fits seamlessly with surrounding code. \
        Do not include anything else beyond the code.

        When you see the prompt "Continue generating", you should continue generating the response.
        For example, if your previous response is:
        ```
        print(Hell
        ```

        You should continue with:
        ```
        o World)
        ```
        """
        var sourceRequest: SuggestionRequest
        var prefix: [String]
        var suffix: [String]
        var filePath: String { sourceRequest.fileURL.path }
        var relevantCodeSnippets: [RelevantCodeSnippet] { sourceRequest.relevantCodeSnippets }
        var stopWords: [String] { [Tag.closingCode, "\n\n"] }
        
        var suggestionPrefix: SuggestionPrefix {
            guard let prefix = prefix.last else { return .empty }
            return .unchanged(prefix).curlyBracesLineBreak()
        }

        func createPrompt(
            truncatedPrefix: [String],
            truncatedSuffix: [String],
            includedSnippets: [RelevantCodeSnippet]
        ) -> [PromptMessage] {
            return createSourcePrompt(
                truncatedPrefix: truncatedPrefix,
                truncatedSuffix: truncatedSuffix,
                includedSnippets: includedSnippets
            )
        }

        func createSourcePrompt(
            truncatedPrefix: [String],
            truncatedSuffix: [String],
            includedSnippets: [RelevantCodeSnippet]
        ) -> [PromptMessage] {
            guard let (summary, infillBlock) = Self.createCodeSummary(
                truncatedPrefix: truncatedPrefix,
                truncatedSuffix: truncatedSuffix,
                suggestionPrefix: suggestionPrefix.infillValue
            ) else { return [] }

            let snippets = Self.createSnippetsPrompt(includedSnippets: includedSnippets)

            let initialPrompt = PromptMessage(role: .user, content: """
            \(snippets)

            Below is the code from file \(filePath) that you are trying to complete.
            Review the code carefully, detect the functionality, formats, style, patterns, \
            and logics in use and use them to predict the completion. \
            Make sure your completion has the correct syntax and formatting. \
            Do not duplicate existing implementations.

            File Path: \(filePath)
            Language: Swift
            Indentation: \
            \(sourceRequest.indentSize) \(sourceRequest.usesTabsForIndentation ? "tab" : "space")

            ---

            Here is the code:
            ```swift
            \(summary)
            ```

            Complete code inside \(Tag.openingCode)
            """)

            let mockResponse = PromptMessage(role: .assistant, content: """
            \(infillBlock)<|stop|>
            """)

            let continuePrompt = PromptMessage(role: .user, content: """
            Continue generating at <|stop|>. \
            Do not put the response in a markdown code block. \
            Do not try to fix what was written. \
            Do not worry about typos.
            """)

            return [
                initialPrompt,
                mockResponse,
                continuePrompt,
            ]
        }

        static func createSnippetsPrompt(includedSnippets: [RelevantCodeSnippet]) -> String {
            guard !includedSnippets.isEmpty else { return "" }
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

        static func createCodeSummary(
            truncatedPrefix: [String],
            truncatedSuffix: [String],
            suggestionPrefix: String
        ) -> (summary: String, infillBlock: String)? {
            guard !(truncatedPrefix.isEmpty && truncatedSuffix.isEmpty) else { return nil }
            let promptLinesCount = min(4, max(truncatedPrefix.count, 2))
            let prefixLines = truncatedPrefix.prefix(truncatedPrefix.count - promptLinesCount)
            let promptLines: [String] = {
                let proposed = truncatedPrefix.suffix(promptLinesCount)
                return Array(proposed.dropLast()) + [suggestionPrefix]
            }()

            return (
                summary: "\(prefixLines.joined())\(Tag.openingCode)\(Tag.closingCode)\(truncatedSuffix.joined())",
                infillBlock: promptLines.joined()
            )
        }
    }

    func postProcessRawSuggestion(suggestionPrefix: String, suggestion: String) -> String {
        let suggestion = extractSuggestion(
            from: suggestion,
            openingTag: Tag.openingCode,
            closingTag: Tag.closingCode
        )

        if suggestion.hasPrefix(suggestionPrefix) {
            var processed = suggestion
            processed.removeFirst(prefix.count)
            return processed
        }

        return suggestionPrefix + suggestion
    }
}

