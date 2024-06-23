import CodeCompletionService
import CopilotForXcodeKit
import Foundation
import Fundamental

/// https://ollama.com/library/codellama
struct FillInTheMiddleRequestStrategy: RequestStrategy {
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

    func createStreamStopStrategy(model: Service.Model) -> some StreamStopStrategy {
        FIMStreamStopStrategy(prefix: prefix)
    }

    func createRawSuggestionPostProcessor() -> some RawSuggestionPostProcessingStrategy {
        DefaultRawSuggestionPostProcessingStrategy(codeWrappingTags: nil)
    }

    enum Tag {
        public static var stop: String { UserDefaults.shared.value(for: \.fimStopToken) }
    }

    struct Prompt: PromptStrategy {
        fileprivate(set) var systemPrompt: String = ""
        var sourceRequest: SuggestionRequest
        var prefix: [String]
        var suffix: [String]
        var filePath: String { sourceRequest.relativePath ?? sourceRequest.fileURL.path }
        var relevantCodeSnippets: [RelevantCodeSnippet] { sourceRequest.relevantCodeSnippets }
        var stopWords: [String] { ["\n\n", Tag.stop].filter { !$0.isEmpty } }
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
            let suffix = truncatedSuffix.joined()
            var template = UserDefaults.shared.value(for: \.fimTemplate)
            if template.isEmpty { template = UserDefaults.shared.defaultValue(for: \.fimTemplate) }
            
            let prefixContent = """
            // File Path: \(filePath)
            // Indentation: \
            \(sourceRequest.indentSize) \
            \(sourceRequest.usesTabsForIndentation ? "tab" : "space")
            \(includedSnippets.map(\.content).joined(separator: "\n\n"))
            \(truncatedPrefix.joined())
            """
            
            let suffixContent = suffix.isEmpty ? "\n// End of file" : suffix
            
            return [
                .init(
                    role: .user,
                    content: template
                        .replacingOccurrences(of: "{prefix}", with: prefixContent)
                        .replacingOccurrences(of: "{suffix}", with: suffixContent)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                ),
            ]
        }
    }
}

struct FillInTheMiddleWithSystemPromptRequestStrategy: RequestStrategy {
    let strategy: FillInTheMiddleRequestStrategy

    init(sourceRequest: SuggestionRequest, prefix: [String], suffix: [String]) {
        strategy = .init(sourceRequest: sourceRequest, prefix: prefix, suffix: suffix)
    }

    func createPrompt() -> some PromptStrategy {
        var prompt = strategy.createPrompt()
        prompt.systemPrompt = """
        You are a senior programer who take the surrounding code and \
        references from the codebase into account in order to write high-quality code to \
        complete the code enclosed in the given code. \
        You only respond with code that works and fits seamlessly with surrounding code. \
        Don't include anything else beyond the code. \
        The prefix will follow the PRE tag and the suffix will follow the SUF tag. \
        You should write the code that fits seamlessly after the MID tag.
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        return prompt
    }

    func createStreamStopStrategy(model: Service.Model) -> some StreamStopStrategy {
        strategy.createStreamStopStrategy(model: model)
    }

    func createRawSuggestionPostProcessor() -> some RawSuggestionPostProcessingStrategy {
        strategy.createRawSuggestionPostProcessor()
    }
}

struct FIMStreamStopStrategy: StreamStopStrategy {
    let prefix: [String]

    func shouldStop(
        existedLines: [String],
        currentLine: String,
        proposedLineLimit: Int
    ) -> StreamStopStrategyResult {
        if let prefixLastLine = prefix.last {
            if let lastLineIndex = existedLines.lastIndex(of: prefixLastLine) {
                if existedLines.count >= lastLineIndex + 1 + proposedLineLimit {
                    return .stop(appendingNewContent: true)
                }
                return .continue
            } else {
                if existedLines.count >= proposedLineLimit {
                    return .stop(appendingNewContent: true)
                }
                return .continue
            }
        } else {
            if existedLines.count >= proposedLineLimit {
                return .stop(appendingNewContent: true)
            }
            return .continue
        }
    }
}

