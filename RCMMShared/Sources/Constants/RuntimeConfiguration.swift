import Foundation

public enum RuntimeConfiguration {
    public static let defaultAppDisplayName = "rcmm"
    public static let defaultAppGroupID = "group.com.sunven.rcmm"
    public static let defaultFinderExtensionBundleID = "com.sunven.rcmm.FinderExtension"
    public static let defaultNotificationPrefix = "com.sunven.rcmm"

    public static var appDisplayName: String {
        stringValue(
            for: "CFBundleDisplayName",
            fallback: defaultAppDisplayName
        )
    }

    public static var appGroupID: String {
        stringValue(
            for: "RCMMAppGroupIdentifier",
            fallback: defaultAppGroupID
        )
    }

    public static var finderExtensionBundleID: String {
        stringValue(
            for: "RCMMFinderExtensionBundleIdentifier",
            fallback: defaultFinderExtensionBundleID
        )
    }

    public static var notificationPrefix: String {
        notificationPrefix(appGroupID: appGroupID)
    }

    static func notificationPrefix(appGroupID: String) -> String {
        appGroupID == defaultAppGroupID ? defaultNotificationPrefix : appGroupID
    }

    static func stringValue(
        for key: String,
        fallback: String,
        bundle: Bundle = .main
    ) -> String {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else {
            return fallback
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else {
            return fallback
        }
        return trimmed
    }
}
