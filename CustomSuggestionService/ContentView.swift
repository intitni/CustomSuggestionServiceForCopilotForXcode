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
                        if CustomModelType(rawValue: chatModelId) != nil {
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
                    if let type = CustomModelType(rawValue: chatModelId) {
                        switch type {
                        case .chatModel:
                            ChatModelEditView(store: store.scope(
                                state: \.customChatModel,
                                action: \.customChatModel
                            ))
                            .frame(width: 800)
                        case .completionModel:
                            CompletionModelEditView(store: store.scope(
                                state: \.customCompletionModel,
                                action: \.customCompletionModel
                            ))
                            .frame(width: 800)
                        }
                    } else {
                        EmptyView()
                    }
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
            !chatModelId.isEmpty,
            CustomModelType(rawValue: chatModelId) == nil
        {
            chatModelId
        } else {
            nil
        }

        Picker(
            selection: $chatModelId,
            label: Text("Model"),
            content: {
                if let unknownId {
                    Text("Unknown Model (Use Custom Model Instead)").tag(unknownId)
                }

                ForEach(CustomModelType.allCases, id: \.rawValue) {
                    switch $0 {
                    case .chatModel:
                        Text("Custom Chat Model").tag($0)
                    case .completionModel:
                        Text("Custom Completion Model").tag($0)
                    }
                }

                ForEach(chatModels, id: \.id) { chatModel in
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
                    case .continue:
                        Text("Continue").tag(option.rawValue)
                    }
                }
            }
        )
    }
}

#Preview {
    ContentView()
}

