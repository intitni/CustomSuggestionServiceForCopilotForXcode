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
    /// By default, it will return the suggestion as is.
    func postProcessRawSuggestion(suggestion: String) -> String
}

public enum RequestStrategyOption: String, CaseIterable, Codable {
    case `default` = ""
    case naive
}

extension RequestStrategyOption {
    var strategy: any RequestStrategy.Type {
        switch self {
        case .default:
            return DefaultRequestStrategy.self
        case .naive:
            return NaiveRequestStrategy.self
        }
    }
}

// MARK: - Default Implementations

extension RequestStrategy {
    func postProcessRawSuggestion(suggestion: String) -> String {
        suggestion
    }
}

