import Foundation

public struct FinderMenuCacheMetadata: Equatable, Sendable {
    public let preferencesModificationDate: Date?
    public let loadedAt: Date

    public init(
        preferencesModificationDate: Date?,
        loadedAt: Date
    ) {
        self.preferencesModificationDate = preferencesModificationDate
        self.loadedAt = loadedAt
    }
}

public enum FinderMenuCacheInvalidationPolicy: Sendable {
    public static let defaultMaximumAgeWhenModificationDateUnavailable: TimeInterval = 2

    public static func shouldReload(
        metadata: FinderMenuCacheMetadata?,
        currentPreferencesModificationDate: Date?,
        now: Date,
        maximumAgeWhenModificationDateUnavailable: TimeInterval = defaultMaximumAgeWhenModificationDateUnavailable
    ) -> Bool {
        guard let metadata else { return true }

        if metadata.preferencesModificationDate != currentPreferencesModificationDate {
            return true
        }

        guard currentPreferencesModificationDate == nil else {
            return false
        }

        return now.timeIntervalSince(metadata.loadedAt) >= maximumAgeWhenModificationDateUnavailable
    }
}
