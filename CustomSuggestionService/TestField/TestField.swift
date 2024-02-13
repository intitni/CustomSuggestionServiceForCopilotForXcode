import Foundation
import ComposableArchitecture

@Reducer
struct TestField {
    @ObservableState
    struct State: Equatable {
        var text: String = ""
    }
    
    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
    }
    
    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { _, action in
            switch action {
            case .binding:
                return .none
            }
        }
    }
}
