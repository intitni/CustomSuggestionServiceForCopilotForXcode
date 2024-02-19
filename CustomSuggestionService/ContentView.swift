import ComposableArchitecture
import Shared
import SuggestionService
import SwiftUI

let store = StoreOf<TheApp>(
    initialState: .init(),
    reducer: { TheApp() }
)

struct ContentView: View {
    @AppStorage(\.chatModelId) var chatModelId

    @State var isEditingCustomModel: Bool = false

    var body: some View {
        ScrollView {
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

                    RequestStrategyPicker()

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
}

struct ExistedChatModelPicker: View {
    @AppStorage(\.chatModelsFromCopilotForXcode) var chatModels: [ChatModel]
    @AppStorage(\.chatModelId) var chatModelId: String

    var body: some View {
        let unknownId: String? =
            if !chatModels.contains(where: { $0.id == chatModelId }),
            !chatModelId.isEmpty
        {
            chatModelId
        } else {
            nil
        }

        Picker(
            selection: $chatModelId,
            label: Text("Chat Model"),
            content: {
                if let unknownId {
                    Text("Unknown Model (Use Custom Model Instead)").tag(unknownId)
                }

                Text("Custom Model").tag("")

                ForEach(
                    chatModels,
                    id: \.id
                ) { chatModel in
                    Text(chatModel.name).tag(chatModel.id)
                }
            }
        )
    }
}

struct RequestStrategyPicker: View {
    @AppStorage(\.requestStrategyId) var requestStrategyId

    var body: some View {
        let unknownId: String? =
            if RequestStrategyOption(rawValue: requestStrategyId) == nil
        {
            requestStrategyId
        } else {
            nil
        }

        Picker(
            selection: $requestStrategyId,
            label: Text("Request Strategy"),
            content: {
                if let unknownId {
                    Text("Unknown Strategy (Use Default Strategy Instead)").tag(unknownId)
                }

                ForEach(
                    RequestStrategyOption.allCases,
                    id: \.rawValue
                ) { option in
                    switch option {
                    case .default:
                        Text("Default").tag(option.rawValue)
                    case .naive:
                        Text("Naive").tag(option.rawValue)
                    }
                }
            }
        )
    }
}

#Preview {
    ContentView()
}

