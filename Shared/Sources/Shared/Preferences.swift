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
    var chatModels: PreferenceKey<[ChatModel]> {
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

    var chatModelId: PreferenceKey<String> {
        .init(defaultValue: "", key: "CustomSuggestionService-SuggestionChatModelId")
    }
}

