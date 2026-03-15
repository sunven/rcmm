import Foundation

public final class SharedConfigService: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: AppGroupConstants.appGroupID)!
    }

    public func save(_ items: [MenuItemConfig]) {
        guard let data = try? JSONEncoder().encode(items) else {
            return
        }
        defaults.set(data, forKey: SharedKeys.menuItems)
    }

    public func load() -> [MenuItemConfig] {
        guard let data = defaults.data(forKey: SharedKeys.menuItems) else {
            return []
        }
        return (try? JSONDecoder().decode([MenuItemConfig].self, from: data)) ?? []
    }

    public func saveCopyPathEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: SharedKeys.copyPathEnabled)
    }

    public func loadCopyPathEnabled() -> Bool {
        defaults.bool(forKey: SharedKeys.copyPathEnabled)
    }
}
