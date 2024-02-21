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
    @AppStorage(\.installBetaBuild) var installBetaBuild
    @AppStorage(\.verboseLog) var verboseLog

    @State var isEditingCustomModel: Bool = false

    @Environment(\.updateChecker) var updateChecker

    var body: some View {
        ScrollView {
            WithPerceptionTracking {
                VStack {
                    Form {
                        HStack {
                            ExistedChatModelPicker()
                            if CustomModelType(rawValue: chatModelId) != nil {
                                Button("Edit Model") {
                                    isEditingCustomModel = true
                                }
                            }
                        }

                        RequestStrategyPicker()

                        Section {
                            HStack {
                                Toggle(isOn: .init(
                                    get: { updateChecker.automaticallyChecksForUpdates },
                                    set: { updateChecker.automaticallyChecksForUpdates = $0 }
                                )) {
                                    Text("Automatically Check for Update")
                                }
                                
                                Button(action: {
                                    updateChecker.checkForUpdates()
                                }) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "arrow.up.right.circle.fill")
                                        Text("Check for Updates")
                                    }
                                }
                            }
                            
                            Toggle("Install Beta Build", isOn: $installBetaBuild)
                            Toggle("Verbose Log (Logs to Console.app)", isOn: $verboseLog)
                        }
                    }
                    .formStyle(.grouped)

                    TestFieldView(store: store.scope(state: \.testField, action: \.testField))
                        .padding(.horizontal, 24)
                }
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
                        case .tabby:
                            TabbyModelEditView(store: store.scope(
                                state: \.tabbyModel,
                                action: \.tabbyModel
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
                        Text("Custom Model (Chat Completion API)").tag($0)
                    case .completionModel:
                        Text("Custom Model (Completion API)").tag($0)
                    case .tabby:
                        Text("Tabby").tag($0)
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
        let unknownId: String? = if RequestStrategyOption(rawValue: requestStrategyId) == nil {
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
        .frame(width: 800, height: 1000)
}

