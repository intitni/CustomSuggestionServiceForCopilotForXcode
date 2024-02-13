import Foundation

public struct CodeCompletionService {
    public init() {}
    
    public enum Error: Swift.Error {
        case unknownFormat
    }
    
    public func getCompletions(
        _ request: PreprocessedSuggestionRequest,
        model: ChatModel,
        count: Int
    ) async throws -> [String] {
        switch model.format {
        case .openAI:
            let service = OpenAIService(modelName: model.info.modelName, apiKey: "")
            return try await service.getCompletions(request, count: count)
        case .azureOpenAI:
            let service = OpenAIService(modelName: model.info.modelName, apiKey: "")
            return try await service.getCompletions(request, count: count)
        case .openAICompatible:
            let service = OpenAIService(modelName: model.info.modelName, apiKey: "")
            return try await service.getCompletions(request, count: count)
        case .googleAI:
            let service = GoogleGeminiService()
            return try await service.getCompletions(request, count: count)
        case .unknown:
            throw Error.unknownFormat
        }
    }
}

protocol CodeCompletionServiceType {
    func getCompletion(
        _ request: PreprocessedSuggestionRequest
    ) async throws -> String
}

extension CodeCompletionServiceType {
    func getCompletions(
        _ request: PreprocessedSuggestionRequest,
        count: Int
    ) async throws -> [String] {
        return try await withThrowingTaskGroup(of: String?.self) { group in
            for _ in 0..<max(1, count) {
                _ = group.addTaskUnlessCancelled {
                    try? await getCompletion(request)
                }
            }

            var result = [String]()
            for try await case let response? in group {
                try Task.checkCancellation()
                result.append(response)
            }

            return result.filter { !$0.isEmpty }
        }
    }
}

