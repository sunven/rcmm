import Foundation

public final class SharedErrorQueue: @unchecked Sendable {
    private static let maxRecords = 20
    private let preferences: SharedPreferencesStore

    public init(defaults: UserDefaults? = nil) {
        preferences = SharedPreferencesStore(defaults: defaults)
    }

    public init(preferences: SharedPreferencesStore) {
        self.preferences = preferences
    }

    /// Note: This method is not atomic across processes. If the main app and extension
    /// call append() simultaneously, one write may be lost. This is acceptable given the
    /// low frequency of error events and the non-critical nature of the error queue.
    public func append(_ error: ErrorRecord) {
        var records = loadAll()
        records.append(error)
        save(records)
    }

    public func upsert(_ error: ErrorRecord) {
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
        preferences.removeObject(forKey: SharedKeys.errorQueue)
    }

    public func remove(key: String) {
        removeAll { $0.key == key }
    }

    public func removeAll(where shouldRemove: (ErrorRecord) -> Bool) {
        let records = loadAll().filter { !shouldRemove($0) }
        replaceAll(with: records)
    }

    /// 用新的记录列表替换队列中的全部内容；传入空数组等同于 removeAll()
    public func replaceAll(with records: [ErrorRecord]) {
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
}
