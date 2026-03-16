import Foundation

public final class SharedConfigService: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: AppGroupConstants.appGroupID)!
    }

    public func saveEntries(_ entries: [MenuEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }
        defaults.set(data, forKey: SharedKeys.menuEntries)
    }

    public func loadEntries() -> [MenuEntry] {
        guard let data = defaults.data(forKey: SharedKeys.menuEntries) else {
            return []
        }
        return (try? JSONDecoder().decode([MenuEntry].self, from: data)) ?? []
    }
}
