import ComposableArchitecture
import Fundamental
import Storage
import SuggestionService
import SwiftUI

let store = StoreOf<TheApp>(
    initialState: .init(),
    reducer: { TheApp() }
)

struct ContentView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.chatModelId) var chatModelId
        @AppStorage(\.installBetaBuild) var installBetaBuild
        @AppStorage(\.verboseLog) var verboseLog
        @AppStorage(\.maxNumberOfLinesOfSuggestion) var maxNumberOfLinesOfSuggestion
        @AppStorage(\.maxGenerationToken) var maxGenerationToken
    }

    @StateObject var settings = Settings()
    @State var isEditingCustomModel: Bool = false

    @Environment(\.updateChecker) var updateChecker

    var body: some View {
        ScrollView {
            WithPerceptionTracking {
                let modelType = CustomModelType(rawValue: settings.chatModelId)
                VStack {
                    Form {
                        Section {
                            HStack {
                                ExistedChatModelPicker()
                                if CustomModelType(rawValue: settings.chatModelId) != nil {
                                    Button("Edit Model") {
                                        isEditingCustomModel = true
                                    }
                                }
                            }

                            switch modelType {
                            case .chatModel, .completionModel, nil:
                                RequestStrategyPicker()
                            case .tabby, .fimModel:
                                EmptyView()
                            }

                            NumberInput(
                                value: settings.$maxNumberOfLinesOfSuggestion,
                                range: 0...Int.max,
                                step: 1
                            ) {
                                Text("Suggestion Line Limit (0 for unlimited)")
                            }
                            
                            NumberInput(
                                value: settings.$maxGenerationToken,
                                range: 0...Int.max,
                                step: 100
                            ) {
                                Text("Suggestion Token Limit")
                            }
                        }

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

                            Toggle("Install Beta Build", isOn: settings.$installBetaBuild)
                            Toggle("Verbose Log (Logs to Console.app)", isOn: settings.$verboseLog)
                        }
                    }
                    .formStyle(.grouped)

                    TestFieldView(store: store.scope(state: \.testField, action: \.testField))
                        .padding(.horizontal, 24)
                }
                .sheet(isPresented: $isEditingCustomModel) {
                    if let type = modelType {
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
                        case .fimModel:
                            FIMModelEditView(store: store.scope(
                                state: \.fimModel,
                                action: \.fimModel
                            ))
                            .frame(width: 800)
                        }
                    } else {
                        EmptyView()
                    }
                }
            }
        }
        .handleToast()
    }
}

struct ExistedChatModelPicker: View {
    final class Settings: ObservableObject {
        @AppStorage(\.chatModelsFromCopilotForXcode) var chatModels: [ChatModel]
        @AppStorage(\.chatModelId) var chatModelId: String
    }

    @StateObject var settings = Settings()

    var body: some View {
        let unknownId: String? =
            if !settings.chatModels.contains(where: { $0.id == settings.chatModelId }),
            !settings.chatModelId.isEmpty,
            CustomModelType(rawValue: settings.chatModelId) == nil
        {
            settings.chatModelId
        } else {
            nil
        }

        Picker(
            selection: settings.$chatModelId,
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
                    case .fimModel:
                        Text("Custom Model (FIM API)").tag($0)
                    }
                }

                ForEach(settings.chatModels, id: \.id) { chatModel in
                    Text(chatModel.name).tag(chatModel.id)
                }
            }
        )
    }
}

struct RequestStrategyPicker: View {
    final class Settings: ObservableObject {
        @AppStorage(\.requestStrategyId) var requestStrategyId
        @AppStorage(\.fimTemplate) var fimTemplate
        @AppStorage(\.fimStopToken) var fimStopToken
    }

    @StateObject var settings = Settings()

    var body: some View {
        let option = RequestStrategyOption(rawValue: settings.requestStrategyId)
        let unknownId: String? = if option == nil {
            settings.requestStrategyId
        } else {
            nil
        }

        Picker(
            selection: settings.$requestStrategyId,
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
                    case .codeLlamaFillInTheMiddle:
                        Text(
                            "Fill-in-the-Middle (Good for Codellama:xb-code and other models with Fill-in-the-Middle support)"
                        )
                        .tag(option.rawValue)
                    case .codeLlamaFillInTheMiddleWithSystemPrompt:
                        Text("Fill-in-the-Middle with System Prompt")
                            .tag(option.rawValue)
                    }
                }
            }
        )

        if option == .codeLlamaFillInTheMiddle
            || option == .codeLlamaFillInTheMiddleWithSystemPrompt
        {
            TextField(
                text: $settings.fimTemplate,
                prompt: Text(UserDefaults.shared.defaultValue(for: \.fimTemplate))
            ) { Text("FIM Template") }
            TextField(text: $settings.fimStopToken) { Text("FIM Stop Token") }
        }
    }
}

struct NumberInput<V: Strideable, Label: View>: View {
    @Binding var value: V
    let formatter = NumberFormatter()
    let range: ClosedRange<V>
    let step: V.Stride
    @ViewBuilder var label: () -> Label

    var body: some View {
        TextField(value: .init(get: {
            if value > range.upperBound {
                return range.upperBound
            } else if value < range.lowerBound {
                return range.lowerBound
            } else {
                return value
            }
        }, set: { newValue in
            if newValue > range.upperBound {
                value = range.upperBound
            } else if newValue < range.lowerBound {
                value = range.lowerBound
            } else {
                value = newValue
            }
        }), formatter: formatter, prompt: nil) {
            label()
        }
        .padding(.trailing)
        .overlay(alignment: .trailing) {
            Stepper(
                value: $value,
                in: range,
                step: step
            ) {
                EmptyView()
            }
        }
        .padding(.trailing, 4)
    }
}

#Preview {
    ContentView()
        .frame(width: 800, height: 1000)
}

