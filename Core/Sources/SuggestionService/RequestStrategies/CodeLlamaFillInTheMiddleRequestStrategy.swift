import CopilotForXcodeKit
import Foundation
import Fundamental

/// https://ollama.com/library/codellama
struct CodeLlamaFillInTheMiddleRequestStrategy: RequestStrategy {
    var sourceRequest: SuggestionRequest
    var prefix: [String]
    var suffix: [String]

    var shouldSkip: Bool {
        prefix.last?.trimmingCharacters(in: .whitespaces) == "}"
    }

    func createPrompt() -> Prompt {
        Prompt(
            sourceRequest: sourceRequest,
            prefix: prefix,
            suffix: suffix
        )
    }

    func createRawSuggestionPostProcessor() -> DefaultRawSuggestionPostProcessingStrategy {
        DefaultRawSuggestionPostProcessingStrategy(openingCodeTag: "", closingCodeTag: "")
    }

    enum Tag {
        public static let prefix = "<PRE>"
        public static let suffix = "<SUF>"
        public static let middle = "<MID>"
    }

    struct Prompt: PromptStrategy {
        let systemPrompt: String = """
        You are a senior programer who take the surrounding code and \
        references from the codebase into account in order to write high-quality code to \
        complete the code enclosed in the given code. \
        You only respond with code that works and fits seamlessly with surrounding code. \
        Don't include anything else beyond the code. \
        The prefix will follow the PRE tag and the suffix will follow the SUF tag.
        """
        var sourceRequest: SuggestionRequest
        var prefix: [String]
        var suffix: [String]
        var filePath: String { sourceRequest.relativePath ?? sourceRequest.fileURL.path }
        var relevantCodeSnippets: [RelevantCodeSnippet] { sourceRequest.relevantCodeSnippets }
        var stopWords: [String] { ["\n\n"] }
        var language: CodeLanguage? { sourceRequest.language }

        var suggestionPrefix: SuggestionPrefix {
            guard let prefix = prefix.last else { return .empty }
            return .unchanged(prefix).curlyBracesLineBreak()
        }

        func createPrompt(
            truncatedPrefix: [String],
            truncatedSuffix: [String],
            includedSnippets: [RelevantCodeSnippet]
        ) -> [PromptMessage] {
            return [
                .init(
                    role: .user,
                    content: """
                    \(Tag.prefix) // File Path: \(filePath)
                    // Indentation: \
                    \(sourceRequest.indentSize) \
                    \(sourceRequest.usesTabsForIndentation ? "tab" : "space")
                    \(includedSnippets.map(\.content).joined(separator: "\n\n"))
                    \(truncatedPrefix.joined()) \
                    \(Tag.suffix)\(truncatedSuffix.joined()) \
                    \(Tag.middle)
                    """.trimmingCharacters(in: .whitespacesAndNewlines)
                ),
            ]
        }
    }
}

