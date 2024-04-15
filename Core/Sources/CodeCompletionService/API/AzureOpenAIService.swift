import CopilotForXcodeKit
import Foundation
import Fundamental

public actor AzureOpenAIService {
    let url: URL
    let endpoint: OpenAIService.Endpoint
    let modelName: String
    let maxToken: Int
    let temperature: Double
    let apiKey: String
    let stopWords: [String]

    init(
        url: String? = nil,
        endpoint: OpenAIService.Endpoint,
        modelName: String,
        maxToken: Int? = nil,
        temperature: Double = 0.2,
        stopWords: [String] = [],
        apiKey: String
    ) {
        self.url = url.flatMap(URL.init(string:)) ?? {
            switch endpoint {
            case .chatCompletion:
                URL(string: "https://api.openai.com/v1/chat/completions")!
            case .completion:
                URL(string: "https://api.openai.com/v1/completions")!
            }
        }()

        self.endpoint = endpoint
        self.modelName = modelName
        self.maxToken = maxToken ?? 4096
        self.temperature = temperature
        self.stopWords = stopWords
        self.apiKey = apiKey
    }
}

extension AzureOpenAIService: CodeCompletionServiceType {
    func getCompletion(_ request: PromptStrategy) async throws -> AsyncStream<String> {
        switch endpoint {
        case .chatCompletion:
            let messages = createMessages(from: request)
            CodeCompletionLogger.logger.logPrompt(messages.map {
                ($0.content, $0.role.rawValue)
            })
            return AsyncStream<String> { continuation in
                let task = Task {
                    let result = try await sendMessages(messages)
                    try Task.checkCancellation()
                    continuation.yield(result)
                    continuation.finish()
                }
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        case .completion:
            let prompt = createPrompt(from: request)
            CodeCompletionLogger.logger.logPrompt([(prompt, "user")])
            return AsyncStream<String> { continuation in
                let task = Task {
                    let result = try await sendPrompt(prompt)
                    try Task.checkCancellation()
                    continuation.yield(result)
                    continuation.finish()
                }
                continuation.onTermination = { _ in
                    task.cancel()
                }
            }
        }
    }
}

extension AzureOpenAIService {
    public typealias Message = OpenAIService.Message
    public typealias APIError = OpenAIService.APIError
    public typealias Error = OpenAIService.Error

    func createMessages(from request: PromptStrategy) -> [Message] {
        let strategy = DefaultTruncateStrategy(maxTokenLimit: max(
            maxToken / 3 * 2,
            maxToken - 300 - 20
        ))
        let prompts = strategy.createTruncatedPrompt(promptStrategy: request)
        return [
            .init(role: .system, content: request.systemPrompt),
        ] + prompts.map { prompt in
            switch prompt.role {
            case .user:
                return .init(role: .user, content: prompt.content)
            case .assistant:
                return .init(role: .assistant, content: prompt.content)
            }
        }
    }

    func sendMessages(_ messages: [Message]) async throws -> String {
        let requestBody = OpenAIService.ChatCompletionRequestBody(
            model: modelName,
            messages: messages,
            temperature: temperature,
            stop: stopWords,
            max_tokens: 300
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        let (result, response) = try await URLSession.shared.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw CancellationError()
        }

        guard response.statusCode == 200 else {
            if let error = try? JSONDecoder().decode(APIError.self, from: result) {
                throw Error.apiError(error)
            }
            throw Error.otherError(String(data: result, encoding: .utf8) ?? "Unknown Error")
        }

        do {
            let body = try JSONDecoder().decode(
                OpenAIService.ChatCompletionResponseBody.self,
                from: result
            )
            return body.choices.first?.message.content ?? ""
        } catch {
            dump(error)
            throw Error.decodeError(error)
        }
    }

    func createPrompt(from request: PromptStrategy) -> String {
        let strategy = DefaultTruncateStrategy(maxTokenLimit: max(
            maxToken / 3 * 2,
            maxToken - 300 - 20
        ))
        let prompts = strategy.createTruncatedPrompt(promptStrategy: request)
        return ([request.systemPrompt] + prompts.map(\.content)).joined(separator: "\n\n")
    }

    func sendPrompt(_ prompt: String) async throws -> String {
        let requestBody = OpenAIService.CompletionRequestBody(
            model: modelName,
            prompt: prompt,
            temperature: temperature,
            stop: stopWords,
            max_tokens: 300
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "api-key")
        let (result, response) = try await URLSession.shared.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw CancellationError()
        }

        guard response.statusCode == 200 else {
            if let error = try? JSONDecoder().decode(APIError.self, from: result) {
                throw Error.apiError(error)
            }
            throw Error.otherError(String(data: result, encoding: .utf8) ?? "Unknown Error")
        }

        do {
            let body = try JSONDecoder().decode(
                OpenAIService.CompletionResponseBody.self,
                from: result
            )
            return body.choices.first?.text ?? ""
        } catch {
            dump(error)
            throw Error.decodeError(error)
        }
    }

    func countToken(_ message: Message) -> Int {
        message.content.count
    }
}

