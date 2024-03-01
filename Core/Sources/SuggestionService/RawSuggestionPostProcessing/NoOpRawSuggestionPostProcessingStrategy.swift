import Foundation

struct NoOpRawSuggestionPostProcessingStrategy: RawSuggestionPostProcessingStrategy {
    func postProcessRawSuggestion(suggestionPrefix: String, suggestion: String) -> String {
        suggestionPrefix + suggestion
    }
}

