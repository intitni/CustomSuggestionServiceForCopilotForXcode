import CopilotForXcodeKit
import Foundation
import Shared

public final class SuggestionService: SuggestionServiceType {
    public init() {}

    public var configuration: SuggestionServiceConfiguration {
        .init(acceptsRelevantCodeSnippets: true)
    }

    public func notifyAccepted(_ suggestion: CodeSuggestion, workspace: WorkspaceInfo) async {}

    public func notifyRejected(_ suggestions: [CodeSuggestion], workspace: WorkspaceInfo) async {}

    public func cancelRequest(workspace: WorkspaceInfo) async {}

    public func getSuggestions(
        _ request: SuggestionRequest,
        workspace: WorkspaceInfo
    ) async throws -> [CodeSuggestion] {
        try await CodeCompletionLogger.$logger.withValue(.init(request: request)) {
            let lines = request.content.breakLines()
            let (previousLines, nextLines, prefix) = split(
                code: request.content,
                lines: lines,
                at: request.cursorPosition
            )
            let strategy = DefaultRequestStrategy(
                sourceRequest: request,
                prefix: previousLines,
                suffix: nextLines
            )
            let service = CodeCompletionService()
            let suggestedCodeSnippets = try await service.getCompletions(
                strategy.createRequest(),
                model: getModel(),
                count: 1
            )
            
            return suggestedCodeSnippets
                .filter { !$0.allSatisfy { $0.isWhitespace || $0.isNewline } }
                .map {
                    .init(
                        id: UUID().uuidString,
                        text: prefix + $0,
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
    
    func getModel() -> ChatModel {
        let id = UserDefaults.shared.value(for: \.chatModelId)
        let models = UserDefaults.shared.value(for: \.chatModels)
        return models.first { $0.id == id } ?? UserDefaults.shared.value(for: \.customChatModel)
    }

    func split(
        code: String,
        lines: [String],
        at cursorPosition: CursorPosition
    ) -> (head: [String], tail: [String], prefix: String) {
        if code.isEmpty { return ([], [], "") }
        if lines.isEmpty { return ([], [], "") }
        if cursorPosition.line < 0 { return ([], lines, "") }
        if cursorPosition.line >= lines.endIndex { return (lines, [], "") }

        let (previousLines, nextLines, prefix): ([String], [String], String) = {
            let previousLines = Array(lines[0..<cursorPosition.line])
            let nextLines = cursorPosition.line + 1 >= lines.endIndex
                ? []
                : Array(lines[(cursorPosition.line + 1)...])
            let splitLine = lines[cursorPosition.line]
            if cursorPosition.character < 0 {
                return (previousLines, [splitLine] + nextLines, "")
            }
            if cursorPosition.character >= splitLine.count {
                return (previousLines + [splitLine], nextLines, splitLine)
            }
            let firstHalf = String(splitLine[..<splitLine.index(
                splitLine.startIndex,
                offsetBy: cursorPosition.character
            )])
            let secondHalf = String(splitLine[splitLine.index(
                splitLine.startIndex,
                offsetBy: cursorPosition.character
            )...])
            return (previousLines + [firstHalf], [secondHalf] + nextLines, firstHalf)
        }()

        return (previousLines, nextLines, prefix)
    }
}


