import Foundation

struct NoOpRawSuggestionPostProcessingStrategy: RawSuggestionPostProcessingStrategy {
    func postProcess(rawSuggestion: String, infillPrefix: String, suffix: [String]) -> String {
        removeTrailingNewlinesAndWhitespace(from: infillPrefix + rawSuggestion)
    }
}

