import Foundation
import GoogleGenerativeAI

public struct GoogleGeminiService {
    let modelName: String
    let temperature: Double
    let stopWords: [String]
    let apiKey: String

    public init(
        modelName: String,
        temperature: Double = 0.2,
        stopWords: [String] = [],
        apiKey: String
    ) {
        self.modelName = modelName
        self.temperature = temperature
        self.stopWords = stopWords
        self.apiKey = apiKey
    }
}

extension GoogleGeminiService: CodeCompletionServiceType {
    func getCompletion(_ request: PromptStrategy) async throws -> String {
        let messages = createMessages(from: request)
        CodeCompletionLogger.logger.logPrompt(messages.map {
            ($0.parts.first?.text ?? "N/A", $0.role ?? "N/A")
        })
        return try await sendMessages(messages)
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

extension GoogleGeminiService {
    public enum Error: Swift.Error, LocalizedError {
        case apiError(Swift.Error)
        case otherError(Swift.Error)

        public var errorDescription: String? {
            switch self {
            case let .apiError(error):
                return "API error: \(error.localizedDescription)"
            case let .otherError(error):
                return "Error: \(error.localizedDescription)"
            }
        }
    }

    func createMessages(from request: PromptStrategy) -> [ModelContent] {
        let prompts = request.createPrompt(
            truncatedPrefix: request.prefix,
            truncatedSuffix: request.suffix,
            includedSnippets: request.relevantCodeSnippets
        )
        return [
            .init(
                role: "user",
                parts: ([request.systemPrompt] + prompts.map(\.content)).joined(separator: "\n\n")
            ),
        ]
    }

    func sendMessages(_ messages: [ModelContent]) async throws -> String {
        let aiModel = GenerativeModel(
            name: modelName,
            apiKey: apiKey,
            generationConfig: .init(GenerationConfig(
                temperature: Float(temperature),
                maxOutputTokens: 300, 
                stopSequences: stopWords
            ))
        )

        do {
            let response = try await aiModel.generateContent(messages)

            return response.candidates.first.map {
                $0.content.parts.first(where: { part in
                    if let text = part.text {
                        return !text.isEmpty
                    } else {
                        return false
                    }
                })?.text ?? ""
            } ?? ""
        } catch let error as GenerateContentError {
            switch error {
            case let .internalError(underlying):
                throw Error.apiError(underlying)
            default:
                throw Error.apiError(error)
            }
        } catch {
            throw Error.otherError(error)
        }
    }
}

