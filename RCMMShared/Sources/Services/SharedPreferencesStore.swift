import Darwin
import Foundation

public final class SharedPreferencesStore: @unchecked Sendable {
    private static let propertyListLockRegistryLock = NSLock()
    nonisolated(unsafe) private static var propertyListLocks: [String: NSLock] = [:]

    private enum Backend {
        case userDefaults(UserDefaults)
        case propertyList(URL)
    }

    private let backend: Backend
    private let fileManager: FileManager
    private let directoryPolicy: DirectoryPolicy

    /// 写入时对父目录的处理方式
    public enum DirectoryPolicy: Sendable {
        /// 目录不存在就创建（主 App 写 Application Scripts 目录时使用）
        case create
        /// 目录必须已存在，否则放弃写入。
        ///
        /// 扩展的沙盒容器只能由 containermanagerd 创建；主 App 抢先建目录会导致容器
        /// 缺少元数据，扩展下次启动时容器结构不完整。
        case requireExisting
    }

    public convenience init(defaults: UserDefaults? = nil) {
        if let defaults {
            self.init(userDefaults: defaults)
        } else {
            self.init(propertyListURL: SharedPaths.extensionScriptsPreferencesURL())
        }
    }

    public init(userDefaults: UserDefaults) {
        backend = .userDefaults(userDefaults)
        fileManager = .default
        directoryPolicy = .create
    }

    public init(
        propertyListURL: URL,
        directoryPolicy: DirectoryPolicy = .create,
        fileManager: FileManager = .default
    ) {
        backend = .propertyList(propertyListURL)
        self.fileManager = fileManager
        self.directoryPolicy = directoryPolicy
    }

    /// 迁移专用：旧版本写在 App Group 容器里的配置路径。
    ///
    /// 该容器会触发 macOS App Data（TCC）门禁，正常读写路径已迁到
    /// `SharedPaths.extensionScriptsPreferencesURL()`。
    public static func legacyAppGroupPreferencesURL(
        appGroupID: String = AppGroupConstants.appGroupID,
        fileManager: FileManager = .default
    ) -> URL? {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            return nil
        }

        return containerURL
            .appendingPathComponent("Library/Preferences")
            .appendingPathComponent(appGroupID)
            .appendingPathExtension("plist")
    }

    public static func propertyListModificationDate(
        at url: URL,
        fileManager: FileManager = .default
    ) -> Date? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
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

    public func modificationDate() -> Date? {
        switch backend {
        case .userDefaults:
            return nil
        case .propertyList(let url):
            return Self.propertyListModificationDate(at: url, fileManager: fileManager)
        }
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
        withLockedPropertyList(exclusive: true) {
            var values = loadPropertyListUnlocked()
            mutate(&values)
            savePropertyListUnlocked(values)
        }
    }

    private func loadPropertyList() -> [String: Any] {
        withLockedPropertyList(exclusive: false) {
            loadPropertyListUnlocked()
        }
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

        let directory = url.deletingLastPathComponent()

        do {
            switch directoryPolicy {
            case .create:
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
            case .requireExisting:
                var isDirectory = ObjCBool(false)
                let exists = fileManager.fileExists(
                    atPath: directory.path,
                    isDirectory: &isDirectory
                )
                guard exists, isDirectory.boolValue else { return }
            }

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

    private func withLockedPropertyList<T>(exclusive: Bool, _ body: () -> T) -> T {
        guard case .propertyList(let url) = backend else {
            return body()
        }

        let inProcessLock = Self.propertyListLock(for: url)
        inProcessLock.lock()
        defer { inProcessLock.unlock() }

        // 扩展对 Application Scripts 只有读权限，不能建锁文件
        // 写路径（exclusive=true）才尝试 flock
        guard exclusive else {
            return body()
        }

        let descriptor = openLockFile(for: url)
        if descriptor >= 0 {
            flock(descriptor, LOCK_EX)
        }
        defer {
            if descriptor >= 0 {
                flock(descriptor, LOCK_UN)
                close(descriptor)
            }
        }

        return body()
    }

    private static func propertyListLock(for url: URL) -> NSLock {
        let key = url.standardizedFileURL.path

        propertyListLockRegistryLock.lock()
        defer { propertyListLockRegistryLock.unlock() }

        if let lock = propertyListLocks[key] {
            return lock
        }

        let lock = NSLock()
        propertyListLocks[key] = lock
        return lock
    }

    private func openLockFile(for url: URL) -> Int32 {
        let lockURL = url.appendingPathExtension("lock")
        let directory = lockURL.deletingLastPathComponent()

        // requireExisting 下不得建目录：扩展沙盒容器只能由 containermanagerd 创建，
        // 这里抢先 mkdir 会留下缺元数据的残缺容器。
        switch directoryPolicy {
        case .create:
            try? fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        case .requireExisting:
            var isDirectory = ObjCBool(false)
            let exists = fileManager.fileExists(
                atPath: directory.path,
                isDirectory: &isDirectory
            )
            guard exists, isDirectory.boolValue else { return -1 }
        }

        return open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    }

    private static func realHomeDirectory() -> URL {
        SharedPaths.realHomeDirectory()
    }
}
