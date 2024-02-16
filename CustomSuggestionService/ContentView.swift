import ComposableArchitecture
import Shared
import SwiftUI

let store = StoreOf<TheApp>(
    initialState: .init(),
    reducer: { TheApp() }
)

struct ContentView: View {
    @AppStorage(\.chatModelId) var chatModelId: String
    @State var isEditingCustomModel: Bool = false

    var body: some View {
        WithPerceptionTracking {
            VStack {
                HStack {
                    ExistedChatModelPicker()
                    if chatModelId.isEmpty {
                        Button("Edit Model") {
                            isEditingCustomModel = true
                        }
                    }
                }
                
                TestFieldView(store: store.scope(state: \.testField, action: \.testField))
            }
            .padding()
            .sheet(isPresented: $isEditingCustomModel) {
                ChatModelEditView(store: store.scope(
                    state: \.customChatModel,
                    action: \.customChatModel
                ))
                .frame(width: 800)
            }
        }
    }
}

#Preview {
    ContentView()
}

