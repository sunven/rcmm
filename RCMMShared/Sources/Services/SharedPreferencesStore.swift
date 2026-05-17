import Darwin
import Foundation

public final class SharedPreferencesStore: @unchecked Sendable {
    private enum Backend {
        case userDefaults(UserDefaults)
        case propertyList(URL)
    }

    private let backend: Backend
    private let fileManager: FileManager
    private let lock = NSLock()

    public convenience init(defaults: UserDefaults? = nil) {
        if let defaults {
            self.init(userDefaults: defaults)
        } else {
            self.init(propertyListURL: Self.appGroupPreferencesURL())
        }
    }

    public init(userDefaults: UserDefaults) {
        backend = .userDefaults(userDefaults)
        fileManager = .default
    }

    public init(
        propertyListURL: URL,
        fileManager: FileManager = .default
    ) {
        backend = .propertyList(propertyListURL)
        self.fileManager = fileManager
    }

    public static func appGroupPreferencesURL(
        appGroupID: String = AppGroupConstants.appGroupID,
        fileManager: FileManager = .default
    ) -> URL {
        let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) ?? realHomeDirectory()
            .appendingPathComponent("Library/Group Containers")
            .appendingPathComponent(appGroupID)

        return containerURL
            .appendingPathComponent("Library/Preferences")
            .appendingPathComponent(appGroupID)
            .appendingPathExtension("plist")
    }

    public func data(forKey key: String) -> Data? {
        value(forKey: key) as? Data
    }

    public func string(forKey key: String) -> String? {
        value(forKey: key) as? String
    }

    public func bool(forKey key: String) -> Bool {
        value(forKey: key) as? Bool ?? false
    }

    public func object(forKey key: String) -> Any? {
        value(forKey: key)
    }

    public func set(_ value: Any, forKey key: String) {
        switch backend {
        case .userDefaults(let defaults):
            defaults.set(value, forKey: key)
        case .propertyList:
            updatePropertyList { values in
                values[key] = value
            }
        }
    }

    public func removeObject(forKey key: String) {
        switch backend {
        case .userDefaults(let defaults):
            defaults.removeObject(forKey: key)
        case .propertyList:
            updatePropertyList { values in
                values.removeValue(forKey: key)
            }
        }
    }

    private func value(forKey key: String) -> Any? {
        switch backend {
        case .userDefaults(let defaults):
            return defaults.object(forKey: key)
        case .propertyList:
            return loadPropertyList()[key]
        }
    }

    private func updatePropertyList(_ mutate: (inout [String: Any]) -> Void) {
        lock.lock()
        defer { lock.unlock() }

        var values = loadPropertyListUnlocked()
        mutate(&values)
        savePropertyListUnlocked(values)
    }

    private func loadPropertyList() -> [String: Any] {
        lock.lock()
        defer { lock.unlock() }
        return loadPropertyListUnlocked()
    }

    private func loadPropertyListUnlocked() -> [String: Any] {
        guard case .propertyList(let url) = backend,
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ),
              let values = plist as? [String: Any] else {
            return [:]
        }
        return values
    }

    private func savePropertyListUnlocked(_ values: [String: Any]) {
        guard case .propertyList(let url) = backend else { return }

        do {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try PropertyListSerialization.data(
                fromPropertyList: values,
                format: .binary,
                options: 0
            )
            try data.write(to: url, options: .atomic)
        } catch {
            assertionFailure("Failed to write shared preferences: \(error)")
        }
    }

    private static func realHomeDirectory() -> URL {
        if let passwd = getpwuid(getuid()),
           let home = passwd.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: home), isDirectory: true)
        }

        return FileManager.default.homeDirectoryForCurrentUser
    }
}
