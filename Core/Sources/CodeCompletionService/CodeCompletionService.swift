import Foundation
import Fundamental
import Storage

protocol CodeCompletionServiceType {
    associatedtype CompletionSequence: AsyncSequence where CompletionSequence.Element == String

    func getCompletion(_ request: PromptStrategy) async throws -> CompletionSequence
}

extension CodeCompletionServiceType {
    func getCompletions(
        _ request: PromptStrategy,
        count: Int
    ) async throws -> [String] {
        try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<max(1, count) {
                _ = group.addTaskUnlessCancelled {
                    var result = ""
                    let stream = try await getCompletion(request)
                    for try await response in stream {
                        result.append(response)
                    }
                    return result
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

public struct CodeCompletionService {
    public init() {}

    public enum Error: Swift.Error {
        case unknownFormat
    }

    public func getCompletions(
        _ prompt: PromptStrategy,
        model: TabbyModel,
        count: Int
    ) async throws -> [String] {
        let apiKey = apiKey(from: model)

        let service = TabbyService(url: model.url, authorizationMode: {
            switch model.authorizationMode {
            case .none:
                return .none
            case .bearerToken:
                return .bearerToken(apiKey)
            case .basic:
                return .basic(username: model.username, password: apiKey)
            case .customHeaderField:
                return .customHeaderField(name: model.authorizationHeaderName, value: apiKey)
            }
        }())

        let result = try await service.getCompletions(prompt, count: count)
        try Task.checkCancellation()
        return result
    }

    public func getCompletions(
        _ prompt: PromptStrategy,
        model: ChatModel,
        count: Int
    ) async throws -> [String] {
        let apiKey = apiKey(from: model)

        switch model.format {
        case .openAI, .openAICompatible:
            let service = OpenAIService(
                url: model.endpoint,
                endpoint: .chatCompletion,
                modelName: model.info.modelName,
                stopWords: prompt.stopWords,
                apiKey: apiKey
            )
            let result = try await service.getCompletions(prompt, count: count)
            try Task.checkCancellation()
            return result
        case .azureOpenAI:
            let service = AzureOpenAIService(
                url: model.endpoint,
                endpoint: .chatCompletion,
                modelName: model.info.modelName,
                stopWords: prompt.stopWords,
                apiKey: apiKey
            )
            let result = try await service.getCompletions(prompt, count: count)
            try Task.checkCancellation()
            return result
        case .googleAI:
            let service = GoogleGeminiService(
                modelName: model.info.modelName,
                maxToken: model.info.maxTokens,
                apiKey: apiKey
            )
            let result = try await service.getCompletions(prompt, count: count)
            try Task.checkCancellation()
            return result
        case .ollama:
            let service = OllamaService(
                url: model.endpoint,
                endpoint: .chatCompletion,
                modelName: model.info.modelName,
                stopWords: prompt.stopWords
            )
            let result = try await service.getCompletions(prompt, count: count)
            try Task.checkCancellation()
            return result
        case .unknown:
            throw Error.unknownFormat
        }
    }

    public func getCompletions(
        _ prompt: PromptStrategy,
        model: CompletionModel,
        count: Int
    ) async throws -> [String] {
        let apiKey = apiKey(from: model)

        switch model.format {
        case .openAI, .openAICompatible:
            let service = OpenAIService(
                url: model.endpoint,
                endpoint: .completion,
                modelName: model.info.modelName,
                stopWords: prompt.stopWords,
                apiKey: apiKey
            )
            let result = try await service.getCompletions(prompt, count: count)
            try Task.checkCancellation()
            return result
        case .azureOpenAI:
            let service = AzureOpenAIService(
                url: model.endpoint,
                endpoint: .completion,
                modelName: model.info.modelName,
                stopWords: prompt.stopWords,
                apiKey: apiKey
            )
            let result = try await service.getCompletions(prompt, count: count)
            try Task.checkCancellation()
            return result
        case .ollama:
            let service = OllamaService(
                url: model.endpoint,
                endpoint: .completion,
                modelName: model.info.modelName,
                stopWords: prompt.stopWords
            )
            let result = try await service.getCompletions(prompt, count: count)
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

    func apiKey(from model: CompletionModel) -> String {
        let name = model.info.apiKeyName
        return (try? Keychain.apiKey.get(name)) ?? ""
    }

    func apiKey(from model: TabbyModel) -> String {
        let name = model.apiKeyName
        return (try? Keychain.apiKey.get(name)) ?? ""
    }
}

