import ComposableArchitecture
import Foundation

@Reducer
struct TheApp {
    @ObservableState
    struct State: Equatable {
        var customChatModel: ChatModelEdit.State = UserDefaults.shared.value(for: \.customChatModel)
            .toState()
        var customCompletionModel: CompletionModelEdit.State = UserDefaults.shared
            .value(for: \.customCompletionModel).toState()
        var tabbyModel: TabbyModelEdit.State = UserDefaults.shared.value(for: \.tabbyModel)
            .toState()
        var fimModel: FIMModelEdit.State = UserDefaults.shared.value(for: \.customFIMModel)
            .toState()
        var testField: TestField.State = .init()
    }

    enum Action: Equatable {
        case customChatModel(ChatModelEdit.Action)
        case customCompletionModel(CompletionModelEdit.Action)
        case tabbyModel(TabbyModelEdit.Action)
        case fimModel(FIMModelEdit.Action)
        case testField(TestField.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.customChatModel, action: \.customChatModel) {
            ChatModelEdit()
        }

        Scope(state: \.customCompletionModel, action: \.customCompletionModel) {
            CompletionModelEdit()
        }

        Scope(state: \.tabbyModel, action: \.tabbyModel) {
            TabbyModelEdit()
        }
        
        Scope(state: \.fimModel, action: \.fimModel) {
            FIMModelEdit()
        }

        Scope(state: \.testField, action: \.testField) {
            TestField()
        }
    }
}

