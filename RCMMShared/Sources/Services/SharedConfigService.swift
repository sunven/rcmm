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
        mirrorLegacyKeys(from: entries)
    }

    public func loadEntries() -> [MenuEntry] {
        if let data = defaults.data(forKey: SharedKeys.menuEntries),
           let entries = try? JSONDecoder().decode([MenuEntry].self, from: data) {
            return entries
        }

        return migrateLegacyEntriesIfNeeded()
    }

    private func migrateLegacyEntriesIfNeeded() -> [MenuEntry] {
        let legacyItems = loadLegacyMenuItems()
        let hasLegacyCopyPathFlag = defaults.object(forKey: SharedKeys.legacyCopyPathEnabled) != nil

        guard !legacyItems.isEmpty || hasLegacyCopyPathFlag else {
            return []
        }

        var entries = legacyItems.map(MenuEntry.custom)
        if hasLegacyCopyPathFlag {
            entries.append(
                .builtIn(
                    BuiltInMenuItem(
                        type: .copyPath,
                        isEnabled: defaults.bool(forKey: SharedKeys.legacyCopyPathEnabled)
                    )
                )
            )
        }

        saveEntries(entries)
        return entries
    }

    private func loadLegacyMenuItems() -> [MenuItemConfig] {
        guard let data = defaults.data(forKey: SharedKeys.legacyMenuItems) else {
            return []
        }

        return (try? JSONDecoder().decode([MenuItemConfig].self, from: data)) ?? []
    }

    private func mirrorLegacyKeys(from entries: [MenuEntry]) {
        let customItems = entries.compactMap { entry -> MenuItemConfig? in
            if case .custom(let config) = entry {
                return config
            }
            return nil
        }
        let legacyItems = customItems.enumerated().map { index, item in
            LegacyMenuItemConfig(item: item, sortOrder: index)
        }

        if let legacyData = try? JSONEncoder().encode(legacyItems) {
            defaults.set(legacyData, forKey: SharedKeys.legacyMenuItems)
        }

        let copyPathEnabled = entries.contains { entry in
            if case .builtIn(let item) = entry {
                return item.type == .copyPath && item.isEnabled
            }
            return false
        }
        defaults.set(copyPathEnabled, forKey: SharedKeys.legacyCopyPathEnabled)
    }
}

private struct LegacyMenuItemConfig: Codable {
    let id: UUID
    let appName: String
    let bundleId: String?
    let appPath: String
    let customCommand: String?
    let sortOrder: Int
    let isEnabled: Bool

    init(item: MenuItemConfig, sortOrder: Int) {
        id = item.id
        appName = item.appName
        bundleId = item.bundleId
        appPath = item.appPath
        customCommand = item.customCommand
        self.sortOrder = sortOrder
        isEnabled = item.isEnabled
    }
}
