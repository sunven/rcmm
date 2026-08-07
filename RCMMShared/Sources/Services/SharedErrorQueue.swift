import Foundation

public final class SharedErrorQueue: @unchecked Sendable {
    private static let maxRecords = 20
    private let preferences: SharedPreferencesStore

    /// 写入前是否需要确认扩展容器已由系统建立。
    ///
    /// 仅默认初始化（真实容器路径）时为 true；注入 preferences 时由调用方自行决定位置。
    private let requiresExtensionContainer: Bool

    public init(defaults: UserDefaults? = nil) {
        if let defaults {
            preferences = SharedPreferencesStore(userDefaults: defaults)
            requiresExtensionContainer = false
        } else {
            // 错误队列放在扩展沙盒容器内，扩展和 App 都可读写，且不经过 App Data 门禁
            preferences = SharedPreferencesStore(
                propertyListURL: SharedPaths.extensionContainerErrorQueueURL(),
                directoryPolicy: .requireExisting
            )
            requiresExtensionContainer = true
        }
    }

    public init(preferences: SharedPreferencesStore) {
        self.preferences = preferences
        requiresExtensionContainer = false
    }

    /// Note: This method is not atomic across processes. If the main app and extension
    /// call append() simultaneously, one write may be lost. This is acceptable given the
    /// low frequency of error events and the non-critical nature of the error queue.
    public func append(_ error: ErrorRecord) {
        guard canWrite else { return }
        var records = loadAll()
        records.append(error)
        save(records)
    }

    public func upsert(_ error: ErrorRecord) {
        guard canWrite else { return }
        guard let key = error.key else {
            append(error)
            return
        }

        var records = loadAll().filter { $0.key != key }
        records.append(error)
        save(records)
    }

    public func loadAll() -> [ErrorRecord] {
        guard let data = preferences.data(forKey: SharedKeys.errorQueue) else {
            return []
        }
        return (try? JSONDecoder().decode([ErrorRecord].self, from: data)) ?? []
    }

    public func removeAll() {
        guard canWrite else { return }
        preferences.removeObject(forKey: SharedKeys.errorQueue)
    }

    public func remove(key: String) {
        removeAll { $0.key == key }
    }

    public func removeAll(where shouldRemove: (ErrorRecord) -> Bool) {
        guard canWrite else { return }
        let records = loadAll().filter { !shouldRemove($0) }
        replaceAll(with: records)
    }

    /// 用新的记录列表替换队列中的全部内容；传入空数组等同于 removeAll()
    public func replaceAll(with records: [ErrorRecord]) {
        guard canWrite else { return }
        if records.isEmpty {
            removeAll()
            return
        }
        let trimmed = records.count > SharedErrorQueue.maxRecords
            ? Array(records.suffix(SharedErrorQueue.maxRecords))
            : records
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        preferences.set(data, forKey: SharedKeys.errorQueue)
    }

    private func save(_ records: [ErrorRecord]) {
        guard canWrite else { return }
        if records.isEmpty {
            removeAll()
            return
        }
        let trimmed = records.count > SharedErrorQueue.maxRecords
            ? Array(records.suffix(SharedErrorQueue.maxRecords))
            : records
        guard let data = try? JSONEncoder().encode(trimmed) else {
            return
        }
        preferences.set(data, forKey: SharedKeys.errorQueue)
    }

    /// 容器必须由 containermanagerd 建立后才能写入。
    ///
    /// App 抢先 `mkdir -p` 看似没问题，但容器缺少 `.com.apple.containermanagerd.metadata.plist`，
    /// 会导致后续扩展启动时容器结构不完整。因此写入前不做 `createDirectory`，
    /// 仅在容器已存在时才落盘。
    private var canWrite: Bool {
        guard requiresExtensionContainer else { return true }
        return SharedPaths.extensionContainerExists()
    }
}
