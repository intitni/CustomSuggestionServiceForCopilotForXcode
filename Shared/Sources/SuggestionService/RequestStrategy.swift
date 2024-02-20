import CopilotForXcodeKit
import Foundation
import Shared

/// Prompts may behave differently in different LLMs.
/// This protocol allows for different strategies to be used to generate prompts.
protocol RequestStrategy {
    associatedtype Prompt: PromptStrategy

    init(sourceRequest: SuggestionRequest, prefix: [String], suffix: [String])

    /// Create a prompt to generate code completion.
    func createPrompt() -> Prompt

    /// The AI model may not return a suggestion in a ideal format. You can use it to reformat the
    /// suggestions.
    ///
    /// By default, it will return the prefix + suggestion.
    func postProcessRawSuggestion(linePrefix: String, suggestion: String) -> String
}

public enum RequestStrategyOption: String, CaseIterable, Codable {
    case `default` = ""
    case naive
    case `continue`
}

extension RequestStrategyOption {
    var strategy: any RequestStrategy.Type {
        switch self {
        case .default:
            return DefaultRequestStrategy.self
        case .naive:
            return NaiveRequestStrategy.self
        case .continue:
            return ContinueRequestStrategy.self
        }
    }
}

// MARK: - Default Implementations

extension RequestStrategy {
    func postProcessRawSuggestion(linePrefix: String, suggestion: String) -> String {
        linePrefix + suggestion
    }
}

// MARK: - Shared Implementations

extension RequestStrategy {
    func extractSuggestion(
        from response: String,
        openingTag: String,
        closingTag: String
    ) -> String {
        // 1. If the first line contains <openingCode>, extract until <closingCode> or the end
        
        // 2. <openingCode> is not in the first line, remove it and all lines after it.
        
        // 3. remove <closingCode> and all lines after it.
        
        return response
    }
}

