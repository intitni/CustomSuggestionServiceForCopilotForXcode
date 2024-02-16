import ComposableArchitecture
import CopilotForXcodeKit
import Foundation
import Shared

@Reducer
struct TestField {
    @ObservableState
    struct State: Equatable {
        var text: AttributedString = """
        struct Foo {
            var bar: Int
        }

        /// Cat is a type of animal
        struct Cat
        """

        var relevantCodeSnippets: AttributedString = """
        protocol Animal {
            var name: String { get }
            var age: Int { get }
            var isPet: Bool { get }
        }
        """
        var suggestions: [CodeSuggestion] = []
        var suggestionIndex: Int = 0
        var cursorPosition: CursorPosition = .zero
        var suggestion: AttributedString = ""
        var suggestionRange: CursorRange = .outOfScope
    }

    enum Action: Equatable, BindableAction {
        case appear
        case textChanged(String, CursorPosition)
        case suggestionReceived([CodeSuggestion])
        case suggestionRequestFailed(String)
        case nextSuggestionButtonClicked
        case previousSuggestionButtonClicked
        case generateSuggestionButtonClicked
        case generateSuggestion
        case binding(BindingAction<State>)
    }

    @Dependency(\.suggestionService) var suggestionService
    @Dependency(\.toast) var toast

    let workspace = WorkspaceInfo(
        workspaceURL: .init(filePath: "/"),
        projectURL: .init(filePath: "/")
    )

    enum CancellationID: Hashable {
        case textChanged
    }

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .appear:
                let code = String(state.text.characters[...])
                let lines = code.breakLines()
                let endPosition = code.utf16.count
                let range = endPosition...endPosition
                let cursorRange = convertRangeToCursorRange(range, in: lines)
                state.cursorPosition = cursorRange.end

                return .none

            case let .textChanged(_, position):
                state.cursorPosition = position
                return .run { send in
                    try await Task.sleep(for: .milliseconds(400))
                    await send(.generateSuggestion)
                }.cancellable(id: CancellationID.textChanged, cancelInFlight: true)

            case .generateSuggestion:
                let relevantCodeSnippet = String(state.relevantCodeSnippets.characters[...])
                let text = String(state.text.characters[...])
                let position = state.cursorPosition
                return .run { send in
                    await suggestionService.cancelRequest(workspace: workspace)
                    do {
                        let result = try await suggestionService.getSuggestions(
                            .init(
                                fileURL: .init(filePath: "/file.swift"),
                                content: text,
                                cursorPosition: position,
                                tabSize: 4,
                                indentSize: 1,
                                usesTabsForIndentation: false,
                                relevantCodeSnippets: [
                                    .init(content: relevantCodeSnippet, priority: 999),
                                ]
                            ),
                            workspace: workspace
                        )
                        await send(.suggestionReceived(result))
                    } catch {
                        await send(.suggestionRequestFailed(error.localizedDescription))
                    }
                }

            case let .suggestionReceived(suggestions):
                state.suggestions = suggestions
                state.suggestionIndex = 0
                updateDisplayedSuggestion(&state)
                return .none

            case let .suggestionRequestFailed(error):
                print(error)
                toast(error, .error)

                return .none

            case .nextSuggestionButtonClicked:
                if state.suggestionIndex >= state.suggestions.endIndex - 1 {
                    state.suggestionIndex = 0
                } else {
                    state.suggestionIndex += 1
                }
                updateDisplayedSuggestion(&state)
                return .none

            case .previousSuggestionButtonClicked:
                if state.suggestionIndex <= 0 {
                    state.suggestionIndex = state.suggestions.endIndex - 1
                } else {
                    state.suggestionIndex -= 1
                }
                updateDisplayedSuggestion(&state)
                return .none

            case .generateSuggestionButtonClicked:
                return .run { send in await send(.generateSuggestion) }

            case .binding:
                return .none
            }
        }
    }

    func updateDisplayedSuggestion(_ state: inout State) {
        if state.suggestions.isEmpty {
            state.suggestionRange = .outOfScope
            state.suggestion = ""
        } else {
            state.suggestionRange = state.suggestions[state.suggestionIndex].range
            state.suggestion = .init(state.suggestions[state.suggestionIndex].text)
        }
    }
}

