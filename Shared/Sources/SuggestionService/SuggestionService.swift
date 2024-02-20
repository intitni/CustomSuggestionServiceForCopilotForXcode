import CopilotForXcodeKit
import Foundation
import Shared

public class SuggestionService: SuggestionServiceType {
    let service = Service()

    public init() {}

    public var configuration: SuggestionServiceConfiguration {
        .init(acceptsRelevantCodeSnippets: true)
    }

    public func notifyAccepted(_ suggestion: CodeSuggestion, workspace: WorkspaceInfo) async {}

    public func notifyRejected(_ suggestions: [CodeSuggestion], workspace: WorkspaceInfo) async {}

    public func cancelRequest(workspace: WorkspaceInfo) async {
        await service.cancelRequest()
    }

    public func getSuggestions(
        _ request: SuggestionRequest,
        workspace: WorkspaceInfo
    ) async throws -> [CodeSuggestion] {
        try await service.getSuggestions(request, workspace: workspace)
    }
}

actor Service {
    enum Model {
        case chatModel(ChatModel)
        case completionModel(CompletionModel)
    }

    var onGoingTask: Task<[CodeSuggestion], Error>?

    func cancelRequest() {
        onGoingTask?.cancel()
        onGoingTask = nil
    }

    func getSuggestions(
        _ request: SuggestionRequest,
        workspace: WorkspaceInfo
    ) async throws -> [CodeSuggestion] {
        onGoingTask?.cancel()
        onGoingTask = nil
        let task = Task {
            try await CodeCompletionLogger.$logger.withValue(.init(request: request)) {
                let lines = request.content.breakLines()
                let (previousLines, nextLines) = Self.split(
                    code: request.content,
                    lines: lines,
                    at: request.cursorPosition
                )
                let strategy = getStrategy(
                    sourceRequest: request,
                    prefix: previousLines,
                    suffix: nextLines
                )
                let service = CodeCompletionService()

                let promptStrategy = strategy.createPrompt()

                let suggestedCodeSnippets = switch getModel() {
                case let .chatModel(model):
                    try await service.getCompletions(promptStrategy, model: model, count: 1)
                case let .completionModel(model):
                    try await service.getCompletions(promptStrategy, model: model, count: 1)
                }

                return suggestedCodeSnippets
                    .filter { !$0.allSatisfy { $0.isWhitespace || $0.isNewline } }
                    .map {
                        CodeSuggestion(
                            id: UUID().uuidString,
                            text: strategy.postProcessRawSuggestion(
                                suggestionPrefix: promptStrategy.suggestionPrefix.prependingValue,
                                suggestion: $0
                            ),
                            position: request.cursorPosition,
                            range: .init(
                                start: .init(
                                    line: request.cursorPosition.line,
                                    character: 0
                                ),
                                end: request.cursorPosition
                            )
                        )
                    }
            }
        }
        onGoingTask = task
        return try await task.value
    }

    func getModel() -> Model {
        let id = UserDefaults.shared.value(for: \.chatModelId)
        let models = UserDefaults.shared.value(for: \.chatModelsFromCopilotForXcode)
        if let existedModel = models.first(where: { $0.id == id }) {
            return .chatModel(existedModel)
        }
        let type = CustomModelType(rawValue: id) ?? .default
        switch type {
        case .chatModel:
            return .chatModel(UserDefaults.shared.value(for: \.customChatModel))
        case .completionModel:
            return .completionModel(UserDefaults.shared.value(for: \.customCompletionModel))
        }
    }

    func getStrategy(
        sourceRequest: SuggestionRequest,
        prefix: [String],
        suffix: [String]
    ) -> any RequestStrategy {
        let id = UserDefaults.shared.value(for: \.requestStrategyId)
        let strategyOption = RequestStrategyOption(rawValue: id) ?? .default
        return strategyOption.strategy.init(
            sourceRequest: sourceRequest,
            prefix: prefix,
            suffix: suffix
        )
    }

    static func split(
        code: String,
        lines: [String],
        at cursorPosition: CursorPosition
    ) -> (head: [String], tail: [String]) {
        if code.isEmpty { return ([], []) }
        if lines.isEmpty { return ([], []) }
        if cursorPosition.line < 0 { return ([], lines) }
        if cursorPosition.line >= lines.endIndex { return (lines, []) }

        let (previousLines, nextLines): ([String], [String]) = {
            let previousLines = Array(lines[0..<cursorPosition.line])
            let nextLines = cursorPosition.line + 1 >= lines.endIndex
                ? []
                : Array(lines[(cursorPosition.line + 1)...])
            let splitLine = lines[cursorPosition.line]
            if cursorPosition.character < 0 {
                return (previousLines, [splitLine] + nextLines)
            }
            if cursorPosition.character >= splitLine.count {
                return (previousLines + [splitLine], nextLines)
            }
            let firstHalf = String(splitLine[..<splitLine.index(
                splitLine.startIndex,
                offsetBy: cursorPosition.character
            )])
            let secondHalf = String(splitLine[splitLine.index(
                splitLine.startIndex,
                offsetBy: cursorPosition.character
            )...])
            return (previousLines + [firstHalf], [secondHalf] + nextLines)
        }()

        return (previousLines, nextLines)
    }
}

