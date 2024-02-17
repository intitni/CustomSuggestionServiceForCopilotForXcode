import CopilotForXcodeKit
import Foundation
import Shared

/// Prompts may behave differently in different LLMs.
/// This protocol allows for different strategies to be used to generate prompts.
protocol RequestStrategy {
    associatedtype Request: PreprocessedSuggestionRequest

    init(sourceRequest: SuggestionRequest, prefix: [String], suffix: [String])
    func createRequest() -> Request
}

public enum RequestStrategyOption: String, CaseIterable, Codable {
    case `default`
}

extension RequestStrategyOption {
    var strategy: any RequestStrategy.Type {
        switch self {
        case .default:
            return DefaultRequestStrategy.self
        }
    }
}
