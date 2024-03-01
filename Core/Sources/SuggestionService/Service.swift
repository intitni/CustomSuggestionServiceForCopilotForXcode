import CodeCompletionService
import CopilotForXcodeKit
import Foundation
import Fundamental

actor Service {
    enum Model {
        case chatModel(ChatModel)
        case completionModel(CompletionModel)
        case tabbyModel(TabbyModel)
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
                do {
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

                    if strategy.shouldSkip {
                        throw CancellationError()
                    }

                    let service = CodeCompletionService()

                    let prompt = strategy.createPrompt()
                    let postProcessor = strategy.createRawSuggestionPostProcessor()

                    let suggestedCodeSnippets: [String]

                    switch getModel() {
                    case let .chatModel(model):
                        CodeCompletionLogger.logger.logModel(model)
                        suggestedCodeSnippets = try await service.getCompletions(
                            prompt,
                            model: model,
                            count: 1
                        )
                    case let .completionModel(model):
                        CodeCompletionLogger.logger.logModel(model)
                        suggestedCodeSnippets = try await service.getCompletions(
                            prompt,
                            model: model,
                            count: 1
                        )
                    case let .tabbyModel(model):
                        CodeCompletionLogger.logger.logModel(model)
                        suggestedCodeSnippets = try await service.getCompletions(
                            prompt,
                            model: model,
                            count: 1
                        )
                    }

                    CodeCompletionLogger.logger.finish()

                    return suggestedCodeSnippets
                        .filter { !$0.allSatisfy { $0.isWhitespace || $0.isNewline } }
                        .map {
                            CodeSuggestion(
                                id: UUID().uuidString,
                                text: postProcessor.postProcess(
                                    rawSuggestion: $0,
                                    infillPrefix: prompt.suggestionPrefix.prependingValue,
                                    suffix: prompt.suffix
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
                } catch {
                    CodeCompletionLogger.logger.error(error)
                    throw error
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
        case .tabby:
            return .tabbyModel(UserDefaults.shared.value(for: \.tabbyModel))
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

