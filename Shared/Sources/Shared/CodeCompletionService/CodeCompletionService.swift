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
        CodeCompletionLogger.logger.logChatModel(model)
        defer { CodeCompletionLogger.logger.finish() }

        let apiKey = apiKey(from: model)

        switch model.format {
        case .openAI, .openAICompatible:
            let service = OpenAIService(
                url: model.endpoint,
                modelName: model.info.modelName,
                apiKey: apiKey
            )
            let result = try await service.getCompletions(request, count: count)
            try Task.checkCancellation()
            return result
        case .azureOpenAI:
            let service = AzureOpenAIService(
                url: model.endpoint,
                modelName: model.info.modelName,
                apiKey: apiKey
            )
            let result = try await service.getCompletions(request, count: count)
            try Task.checkCancellation()
            return result
        case .googleAI:
            let service = GoogleGeminiService()
            let result = try await service.getCompletions(request, count: count)
            try Task.checkCancellation()
            return result
        case .unknown:
            throw Error.unknownFormat
        }
    }

    func apiKey(from model: ChatModel) -> String {
        let name = model.info.apiKeyName
        return (try? Keychain.apiKey.get(name)) ?? ""
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
        try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<max(1, count) {
                _ = group.addTaskUnlessCancelled {
                    try await getCompletion(request)
                }
            }

            var result = [String]()
            do {
                for try await case let response in group {
                    try Task.checkCancellation()
                    result.append(response)
                    CodeCompletionLogger.logger.logResponse(response)
                }
            } catch {
                group.cancelAll()
                if result.isEmpty {
                    throw error
                }
            }

            return result.filter { !$0.isEmpty }
        }
    }
}

