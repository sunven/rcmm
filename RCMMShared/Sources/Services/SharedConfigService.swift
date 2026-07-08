import Foundation

public final class SharedConfigService: @unchecked Sendable {
    private let preferences: SharedPreferencesStore

    public init(defaults: UserDefaults? = nil) {
        preferences = SharedPreferencesStore(defaults: defaults)
    }

    public init(preferences: SharedPreferencesStore) {
        self.preferences = preferences
    }

    public func saveEntries(_ entries: [MenuEntry]) {
        let unknownEnvelopes = loadEntryEnvelopes().filter(\.isUnknown)
        let envelopes = entries.map(MenuEntryEnvelope.init(entry:)) + unknownEnvelopes

        guard let data = try? JSONEncoder().encode(envelopes) else {
            return
        }
        preferences.set(data, forKey: SharedKeys.menuEntries)
        mirrorLegacyKeys(from: entries)
    }

    @discardableResult
    public func mergeNewFileTemplateFingerprints(from refreshedEntries: [MenuEntry]) -> Bool {
        let currentEntries = loadEntries()
        let mergedEntries = NewFileTemplateMetadataPolicy.mergingTemplateFingerprints(
            from: refreshedEntries,
            into: currentEntries
        )

        guard mergedEntries != currentEntries else {
            return false
        }

        saveEntries(mergedEntries)
        return true
    }

    public func loadEntries() -> [MenuEntry] {
        let envelopes = loadEntryEnvelopes()
        if !envelopes.isEmpty {
            let entries = envelopes.compactMap(\.entry)
            if !entries.isEmpty || hasSavedEntriesData {
                return entries
            }
        }

        if hasSavedEntriesData {
            return []
        }

        return migrateLegacyEntriesIfNeeded()
    }

    public func loadEntryEnvelopes() -> [MenuEntryEnvelope] {
        guard let data = preferences.data(forKey: SharedKeys.menuEntries) else {
            return []
        }

        if let envelopes = try? JSONDecoder().decode([MenuEntryEnvelope].self, from: data) {
            return envelopes
        }

        if let entries = try? JSONDecoder().decode([MenuEntry].self, from: data) {
            return entries.map(MenuEntryEnvelope.init(entry:))
        }

        return []
    }

    public var hasSavedEntriesData: Bool {
        preferences.data(forKey: SharedKeys.menuEntries) != nil
    }

    public func modificationDate() -> Date? {
        preferences.modificationDate()
    }

    public func saveMenuPresentationMode(_ mode: MenuPresentationMode) {
        preferences.set(mode.rawValue, forKey: SharedKeys.menuPresentationMode)
    }

    public func loadMenuPresentationMode() -> MenuPresentationMode {
        guard let rawValue = preferences.string(forKey: SharedKeys.menuPresentationMode),
              let mode = MenuPresentationMode(rawValue: rawValue) else {
            return .flat
        }

        return mode
    }

    private func migrateLegacyEntriesIfNeeded() -> [MenuEntry] {
        let legacyItems = loadLegacyMenuItems()
        let hasLegacyCopyPathFlag = preferences.object(forKey: SharedKeys.legacyCopyPathEnabled) != nil

        guard !legacyItems.isEmpty || hasLegacyCopyPathFlag else {
            return []
        }

        var entries = legacyItems.map(MenuEntry.custom)
        if hasLegacyCopyPathFlag {
            entries.append(
                .builtIn(
                    BuiltInMenuItem(
                        type: .copyPath,
                        isEnabled: preferences.bool(forKey: SharedKeys.legacyCopyPathEnabled)
                    )
                )
            )
        }

        saveEntries(entries)
        return entries
    }

    private func loadLegacyMenuItems() -> [MenuItemConfig] {
        guard let data = preferences.data(forKey: SharedKeys.legacyMenuItems) else {
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
            preferences.set(legacyData, forKey: SharedKeys.legacyMenuItems)
        }

        let copyPathEnabled = entries.contains { entry in
            if case .builtIn(let item) = entry {
                return item.type == .copyPath && item.isEnabled
            }
            return false
        }
        preferences.set(copyPathEnabled, forKey: SharedKeys.legacyCopyPathEnabled)
    }
}

private struct LegacyMenuItemConfig: Codable {
    let id: UUID
    let appName: String
    let bundleId: String?
    let appPath: String
    let customCommand: String?
    let executionMode: CustomCommandExecutionMode
    let sortOrder: Int
    let isEnabled: Bool

    init(item: MenuItemConfig, sortOrder: Int) {
        id = item.id
        appName = item.appName
        bundleId = item.bundleId
        appPath = item.appPath
        customCommand = item.customCommand
        executionMode = item.executionMode
        self.sortOrder = sortOrder
        isEnabled = item.isEnabled
    }
}
