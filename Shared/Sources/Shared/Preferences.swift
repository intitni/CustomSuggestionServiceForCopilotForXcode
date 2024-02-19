import Foundation

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
    
    var requestStrategyId: PreferenceKey<String> {
        .init(defaultValue: "", key: "CustomSuggestionService-RequestStrategyId")
    }

    var chatModelId: PreferenceKey<String> {
        .init(defaultValue: "", key: "CustomSuggestionService-SuggestionChatModelId")
    }
}

