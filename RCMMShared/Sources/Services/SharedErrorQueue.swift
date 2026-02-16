import Foundation

public final class SharedErrorQueue: @unchecked Sendable {
    private static let maxRecords = 20
    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: AppGroupConstants.appGroupID)!
    }

    /// Note: This method is not atomic across processes. If the main app and extension
    /// call append() simultaneously, one write may be lost. This is acceptable given the
    /// low frequency of error events and the non-critical nature of the error queue.
    public func append(_ error: ErrorRecord) {
        var records = loadAll()
        records.append(error)
        if records.count > SharedErrorQueue.maxRecords {
            records = Array(records.suffix(SharedErrorQueue.maxRecords))
        }
        guard let data = try? JSONEncoder().encode(records) else {
            return
        }
        defaults.set(data, forKey: SharedKeys.errorQueue)
    }

    public func loadAll() -> [ErrorRecord] {
        guard let data = defaults.data(forKey: SharedKeys.errorQueue) else {
            return []
        }
        return (try? JSONDecoder().decode([ErrorRecord].self, from: data)) ?? []
    }

    public func removeAll() {
        defaults.removeObject(forKey: SharedKeys.errorQueue)
    }
}
