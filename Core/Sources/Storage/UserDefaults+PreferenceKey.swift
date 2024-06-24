import Dependencies
import Foundation

public protocol UserDefaultsType {
    func value(forKey: String) -> Any?
    func set(_ value: Any?, forKey: String)
}

public extension UserDefaults {
    static var shared = UserDefaults(suiteName: userDefaultSuiteName)!
}

struct UserDefaultsDependencyKey: DependencyKey {
    static var liveValue: UserDefaultsType = UserDefaults.shared
    static var previewValue: UserDefaultsType = {
        let it = UserDefaults(suiteName: "HostAppPreview")!
        it.removePersistentDomain(forName: "HostAppPreview")
        return it
    }()

    static var testValue: UserDefaultsType = {
        let it = UserDefaults(suiteName: "HostAppTest")!
        it.removePersistentDomain(forName: "HostAppTest")
        return it
    }()
}


public extension DependencyValues {
    var userDefaults: UserDefaultsType {
        get { self[UserDefaultsDependencyKey.self] }
        set { self[UserDefaultsDependencyKey.self] = newValue }
    }
}

extension UserDefaults: UserDefaultsType {}

public protocol UserDefaultsStorable {}

extension Int: UserDefaultsStorable {}
extension Double: UserDefaultsStorable {}
extension Bool: UserDefaultsStorable {}
extension String: UserDefaultsStorable {}
extension Data: UserDefaultsStorable {}
extension URL: UserDefaultsStorable {}

extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}

public struct StorageBox<Element: Codable>: RawRepresentable {
    public let value: Element

    public init(_ value: Element) {
        self.value = value
    }
    
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode(Element.self, from: data)
        else {
            return nil
        }
        value = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(value),
              let result = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return result
    }
}

public extension UserDefaultsType {
    // MARK: Normal Types

    func value<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) -> K.Value where K.Value: UserDefaultsStorable {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        return (value(forKey: key.key) as? K.Value) ?? key.defaultValue
    }
    
    func defaultValue<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) -> K.Value where K.Value: UserDefaultsStorable {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        return key.defaultValue
    }

    func set<K: UserDefaultPreferenceKey>(
        _ value: K.Value,
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value: UserDefaultsStorable {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        set(value, forKey: key.key)
    }

    func setupDefaultValue<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value: UserDefaultsStorable {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        if value(forKey: key.key) == nil {
            set(key.defaultValue, forKey: key.key)
        }
    }

    func setupDefaultValue<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>,
        defaultValue: K.Value
    ) where K.Value: UserDefaultsStorable {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        if value(forKey: key.key) == nil {
            set(defaultValue, forKey: key.key)
        }
    }

    // MARK: Raw Representable

    func value<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) -> K.Value where K.Value: RawRepresentable, K.Value.RawValue == String {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        guard let rawValue = value(forKey: key.key) as? String else {
            return key.defaultValue
        }
        return K.Value(rawValue: rawValue) ?? key.defaultValue
    }

    func value<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) -> K.Value where K.Value: RawRepresentable, K.Value.RawValue == Int {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        guard let rawValue = value(forKey: key.key) as? Int else {
            return key.defaultValue
        }
        return K.Value(rawValue: rawValue) ?? key.defaultValue
    }
    
    func value<K: UserDefaultPreferenceKey, V>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) -> V where K.Value == StorageBox<V> {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        guard let rawValue = value(forKey: key.key) as? String else {
            return key.defaultValue.value
        }
        return (K.Value(rawValue: rawValue) ?? key.defaultValue).value
    }

    func set<K: UserDefaultPreferenceKey>(
        _ value: K.Value,
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value: RawRepresentable, K.Value.RawValue == String {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        set(value.rawValue, forKey: key.key)
    }

    func set<K: UserDefaultPreferenceKey>(
        _ value: K.Value,
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value: RawRepresentable, K.Value.RawValue == Int {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        set(value.rawValue, forKey: key.key)
    }
    
    func set<K: UserDefaultPreferenceKey, V: Codable>(
        _ value: V,
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>
    ) where K.Value == StorageBox<V> {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        set(StorageBox(value).rawValue, forKey: key.key)
    }

    func setupDefaultValue<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>,
        defaultValue: K.Value? = nil
    ) where K.Value: RawRepresentable, K.Value.RawValue == String {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        if value(forKey: key.key) == nil {
            set(defaultValue?.rawValue ?? key.defaultValue.rawValue, forKey: key.key)
        }
    }

    func setupDefaultValue<K: UserDefaultPreferenceKey>(
        for keyPath: KeyPath<UserDefaultPreferenceKeys, K>,
        defaultValue: K.Value? = nil
    ) where K.Value: RawRepresentable, K.Value.RawValue == Int {
        let key = UserDefaultPreferenceKeys()[keyPath: keyPath]
        if value(forKey: key.key) == nil {
            set(defaultValue?.rawValue ?? key.defaultValue.rawValue, forKey: key.key)
        }
    }
}

