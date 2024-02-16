import CopilotForXcodeKit
import Foundation

public final class CodeCompletionLogger {
    @TaskLocal public static var logger: CodeCompletionLogger = .init(request: SuggestionRequest(
        fileURL: .init(filePath: "/"),
        content: "",
        cursorPosition: .zero,
        tabSize: 0,
        indentSize: 0,
        usesTabsForIndentation: false,
        relevantCodeSnippets: []
    ))

    let request: SuggestionRequest
    var chatModel: ChatModel = .init(id: "", name: "", format: .openAI, info: .init())
    var prompt: [(message: String, role: String)] = []
    var responses: [String] = []
    let startTime = Date()

    public init(request: SuggestionRequest) {
        self.request = request
    }
    
    func logChatModel(_ chatModel: ChatModel) {
        self.chatModel = chatModel
    }

    func logPrompt(_ prompt: [(message: String, role: String)]) {
        self.prompt = prompt
    }

    func logResponse(_ response: String) {
        responses.append(response)
    }

    func finish() {
        #if DEBUG

        guard !Task.isCancelled else {
            Logger.service.info("""
            [Request] Cancelled.
            """)
            return
        }

        let now = Date()
        let duration = now.timeIntervalSince(startTime)
        let formattedDuration = String(format: "%.2f", duration)

        Logger.service.info("""
        [Request]

        Format: \(chatModel.format)
        Model Name: \(chatModel.name)
        Base URL: \(chatModel.info.baseURL)
        Duration: \(formattedDuration)
        ---
        File URL: \(request.fileURL)
        Code Snippets: \(request.relevantCodeSnippets.count)
        CursorPosition: \(request.cursorPosition)

        [Prompt]

        \(prompt.map { "\($0.role): \($0.message)" }.joined(separator: "\n\n"))

        [Response]

        \(responses.enumerated().map { "\($0 + 1): \($1)" }.joined(separator: "\n\n"))
        """)

        #endif
    }
}

