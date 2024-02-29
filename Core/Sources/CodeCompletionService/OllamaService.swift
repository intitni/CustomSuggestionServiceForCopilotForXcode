import CopilotForXcodeKit
import Foundation
import Fundamental

public actor OllamaService {
    let url: URL
    let endpoint: Endpoint
    let modelName: String
    let maxToken: Int
    let temperature: Double
    let stopWords: [String]

    public enum Endpoint {
        case completion
        case chatCompletion
    }

    init(
        url: String? = nil,
        endpoint: Endpoint,
        modelName: String,
        maxToken: Int? = nil,
        temperature: Double = 0.2,
        stopWords: [String] = []
    ) {
        self.url = url.flatMap(URL.init(string:)) ?? {
            switch endpoint {
            case .chatCompletion:
                URL(string: "https://127.0.0.1:11434/api/chat")!
            case .completion:
                URL(string: "https://127.0.0.1:11434/api/generate")!
            }
        }()

        self.endpoint = endpoint
        self.modelName = modelName
        self.maxToken = maxToken ?? 4096
        self.temperature = temperature
        self.stopWords = stopWords
    }
}

extension OllamaService: CodeCompletionServiceType {
    typealias CompletionSequence = AsyncThrowingCompactMapSequence<
        ResponseStream<OllamaService.ChatCompletionResponseChunk>,
        String
    >

    func getCompletion(
        _ request: PromptStrategy
    ) async throws -> CompletionSequence {
        switch endpoint {
        case .chatCompletion:
            let messages = createMessages(from: request)
            CodeCompletionLogger.logger.logPrompt(messages.map {
                ($0.content, $0.role.rawValue)
            })
            let stream = try await sendMessages(messages)
            return stream.compactMap { $0.message?.content }
        case .completion:
            let prompt = createPrompt(from: request)
            CodeCompletionLogger.logger.logPrompt([(prompt, "user")])
            let stream = try await sendPrompt(prompt)
            return stream.compactMap { $0.response }
        }
    }
}

extension OllamaService {
    struct Message: Codable, Equatable {
        public enum Role: String, Codable {
            case user
            case assistant
            case system
        }

        /// The role of the message.
        public var role: Role
        /// The content of the message.
        public var content: String
    }

    enum Error: Swift.Error, LocalizedError {
        case decodeError(Swift.Error)
        case otherError(String)

        public var errorDescription: String? {
            switch self {
            case let .decodeError(error):
                return error.localizedDescription
            case let .otherError(message):
                return message
            }
        }
    }
}

// MARK: - Chat Completion API

/// https://github.com/ollama/ollama/blob/main/docs/api.md#chat-request-streaming
extension OllamaService {
    struct ChatCompletionRequestBody: Codable {
        struct Options: Codable {
            var temperature: Double
            var stop: [String]
            var num_predict: Int
            var top_k: Int?
            var top_p: Double?
        }

        var model: String
        var messages: [Message]
        var stream: Bool
        var options: Options
    }

    struct ChatCompletionResponseChunk: Decodable {
        var model: String
        var message: Message?
        var response: String?
        var done: Bool
        var total_duration: Int64?
        var load_duration: Int64?
        var prompt_eval_count: Int?
        var prompt_eval_duration: Int64?
        var eval_count: Int?
        var eval_duration: Int64?
    }

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

    func sendMessages(_ messages: [Message]) async throws
        -> ResponseStream<ChatCompletionResponseChunk>
    {
        let requestBody = ChatCompletionRequestBody(
            model: modelName,
            messages: messages,
            stream: true,
            options: .init(
                temperature: temperature,
                stop: stopWords,
                num_predict: 300
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (result, response) = try await URLSession.shared.bytes(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw CancellationError()
        }

        guard response.statusCode == 200 else {
            let text = try await result.lines.reduce(into: "") { partialResult, current in
                partialResult += current
            }
            throw Error.otherError(text)
        }

        return ResponseStream(result: result)
    }
}

// MARK: - Completion API

extension OllamaService {
    struct CompletionRequestBody: Codable {
        var model: String
        var prompt: String
        var stream: Bool
        var options: ChatCompletionRequestBody.Options
    }

    func createPrompt(from request: PromptStrategy) -> String {
        let strategy = DefaultTruncateStrategy(maxTokenLimit: max(
            maxToken / 3 * 2,
            maxToken - 300 - 20
        ))
        let prompts = strategy.createTruncatedPrompt(promptStrategy: request)
        return ([request.systemPrompt] + prompts.map(\.content)).joined(separator: "\n\n")
    }

    func sendPrompt(_ prompt: String) async throws -> ResponseStream<ChatCompletionResponseChunk> {
        let requestBody = CompletionRequestBody(
            model: modelName,
            prompt: prompt,
            stream: true,
            options: .init(
                temperature: temperature,
                stop: stopWords,
                num_predict: 300
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(requestBody)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (result, response) = try await URLSession.shared.bytes(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw CancellationError()
        }

        guard response.statusCode == 200 else {
            let text = try await result.lines.reduce(into: "") { partialResult, current in
                partialResult += current
            }
            throw Error.otherError(text)
        }

        return ResponseStream(result: result)
    }

    func countToken(_ message: Message) -> Int {
        message.content.count
    }
}

