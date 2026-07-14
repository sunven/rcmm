import Foundation

public final class ApplicationIconStore: @unchecked Sendable {
    private let preferences: SharedPreferencesStore

    public init(defaults: UserDefaults? = nil) {
        preferences = SharedPreferencesStore(defaults: defaults)
    }

    public init(preferences: SharedPreferencesStore) {
        self.preferences = preferences
    }

    public func saveIcons(_ icons: [String: Data]) {
        guard let data = try? PropertyListEncoder().encode(icons) else {
            return
        }
        preferences.set(data, forKey: SharedKeys.applicationIcons)
    }

    public func loadIcons() -> [String: Data] {
        guard let data = preferences.data(forKey: SharedKeys.applicationIcons) else {
            return [:]
        }
        return (try? PropertyListDecoder().decode([String: Data].self, from: data)) ?? [:]
    }
}
