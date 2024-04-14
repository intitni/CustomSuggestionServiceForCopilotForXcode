import Foundation
import Fundamental

public struct UserDefaultPreferenceKeys {
    public init() {}
}

public protocol UserDefaultPreferenceKey {
    associatedtype Value
    var defaultValue: Value { get }
    var key: String { get }
}

public struct PreferenceKey<T>: UserDefaultPreferenceKey {
    public let defaultValue: T
    public let key: String

    public init(defaultValue: T, key: String) {
        self.defaultValue = defaultValue
        self.key = key
    }
}

public extension UserDefaultPreferenceKeys {
    /// Access the chat models set in Copilot for Xcode.
    ///
    /// - Note: It only works when they are in the same app group.
    var chatModelsFromCopilotForXcode: PreferenceKey<[ChatModel]> {
        .init(defaultValue: [], key: "ChatModels")
    }

    var serviceType: PreferenceKey<String> {
        .init(defaultValue: "", key: "CustomSuggestionService-ServiceType")
    }

    var customChatModel: PreferenceKey<StorageBox<ChatModel>> {
        .init(
            defaultValue: .init(ChatModel(
                id: "ID",
                name: "Custom",
                format: .openAI,
                info: .init()
            )),
            key: "CustomSuggestionService-CustomChatModel"
        )
    }

    var customCompletionModel: PreferenceKey<StorageBox<CompletionModel>> {
        .init(
            defaultValue: .init(CompletionModel(
                id: "ID",
                name: "Custom",
                format: .openAI,
                info: .init()
            )),
            key: "CustomSuggestionService-CustomCompletionModel"
        )
    }

    var requestStrategyId: PreferenceKey<String> {
        .init(defaultValue: "", key: "CustomSuggestionService-RequestStrategyId")
    }

    var chatModelId: PreferenceKey<String> {
        .init(
            defaultValue: CustomModelType.default.rawValue,
            key: "CustomSuggestionService-SuggestionChatModelId"
        )
    }

    var tabbyModel: PreferenceKey<StorageBox<TabbyModel>> {
        .init(
            defaultValue: .init(.init(
                url: "",
                authorizationMode: .none,
                apiKeyName: "",
                authorizationHeaderName: "",
                username: ""
            )),
            key: "CustomSuggestionService-TabbyModel"
        )
    }
    
    var maxNumberOfLinesOfSuggestion: PreferenceKey<Int> {
        .init(
            defaultValue: 99999,
            key: "CustomSuggestionService-MaxNumberOfLinesOfSuggestion"
        )
    }

    var installBetaBuild: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "CustomSuggestionService-InstallBetaBuild")
    }

    var verboseLog: PreferenceKey<Bool> {
        .init(defaultValue: false, key: "CustomSuggestionService-VerboseLog")
    }
}

