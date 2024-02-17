import CopilotForXcodeKit
import Foundation

public actor AzureOpenAIService {
    let url: URL
    let modelName: String
    let maxToken: Int
    let temperature: Double
    let apiKey: String
    let stopWords: [String]

    public init(
        url: String? = nil,
        modelName: String,
        maxToken: Int? = nil,
        temperature: Double = 0.2,
        stopWords: [String] = [],
        apiKey: String
    ) {
        self.url = url.flatMap(URL.init(string:)) ??
            URL(string: "https://api.openai.com/v1/chat/completions")!
        self.modelName = modelName
        self.maxToken = maxToken ?? 4096
        self.temperature = temperature
        self.stopWords = stopWords
        self.apiKey = apiKey
    }
}

extension AzureOpenAIService: CodeCompletionServiceType {
    func getCompletion(_ request: PreprocessedSuggestionRequest) async throws -> String {
        let messages = createMessages(from: request)
        CodeCompletionLogger.logger.logPrompt(messages.map {
            ($0.content, $0.role.rawValue)
        })
        return try await sendMessages(messages)
    }
}

extension AzureOpenAIService {
    public typealias Message = OpenAIService.Message
    public typealias APIError = OpenAIService.APIError
    public typealias Error = OpenAIService.Error

    func createMessages(from request: PreprocessedSuggestionRequest) -> [Message] {
        let prompts = request.createPrompt(
            truncatedPrefix: request.prefix,
            truncatedSuffix: request.suffix,
            includedSnippets: request.relevantCodeSnippets
        )
        return [
            // The result is more correct when there is only one message.
            .init(
                role: .user,
                content: ([request.systemPrompt] + prompts).joined(separator: "\n\n")
            ),
        ]
    }

    func sendMessages(_ messages: [Message]) async throws -> String {
        let requestBody = OpenAIService.CompletionRequestBody(
            model: modelName,
            messages: messages,
            temperature: temperature,
            stop: stopWords
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
            return body.choices.first?.message.content ?? ""
        } catch {
            dump(error)
            throw Error.decodeError(error)
        }
    }

    func countToken(_ message: Message) -> Int {
        message.content.count
    }
}

