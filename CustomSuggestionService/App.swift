import ComposableArchitecture
import Foundation

@Reducer
struct TheApp {
    @ObservableState
    struct State: Equatable {
        var customChatModel: ChatModelEdit.State = .init(format: .openAI)
        var testField: TestField.State = .init()
    }

    enum Action: Equatable {
        case customChatModel(ChatModelEdit.Action)
        case testField(TestField.Action)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.customChatModel, action: \.customChatModel) {
            ChatModelEdit()
        }

        Scope(state: \.testField, action: \.testField) {
            TestField()
        }
    }
}

