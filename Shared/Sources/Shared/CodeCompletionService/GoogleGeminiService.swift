import Foundation

public struct GoogleGeminiService {}

extension GoogleGeminiService: CodeCompletionServiceType {
    func getCompletion(_: PreprocessedSuggestionRequest) async throws -> String {
        throw CancellationError()
    }
}

public extension GoogleGeminiService {
    enum KnownModels: String, CaseIterable {
        case geminiPro = "gemini-pro"

        public var maxToken: Int {
            switch self {
            case .geminiPro:
                return 32768
            }
        }
    }
}

