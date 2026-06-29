import Foundation
import RCMMShared

enum AppBundleUpdateInfoError: Error, Equatable {
    case missingValue(String)
    case invalidValue(String)
}

struct AppBundleUpdateInfo: Sendable {
    let bundlePath: String
    let currentVersion: DevBuildVersion
    let displayVersion: String
    let feedURL: URL?
    let updatesEnabled: Bool
    let releasePageURL: URL

    static func current(bundle: Bundle = .main) throws -> AppBundleUpdateInfo {
        let bundlePath = bundle.bundlePath

        guard
            let bundleVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            let currentVersion = DevBuildVersion.parse(bundleVersion: bundleVersion)
        else {
            throw AppBundleUpdateInfoError.missingValue("CFBundleVersion")
        }

        guard let displayVersion = bundle.object(forInfoDictionaryKey: "RCMMDisplayVersion") as? String else {
            throw AppBundleUpdateInfoError.missingValue("RCMMDisplayVersion")
        }

        let updatesEnabled = boolValue(
            forInfoDictionaryKey: "RCMMUpdatesEnabled",
            bundle: bundle,
            fallback: true
        )
        let feedURL = try urlValue(forInfoDictionaryKey: "SUFeedURL", bundle: bundle)
        if updatesEnabled && feedURL == nil {
            throw AppBundleUpdateInfoError.missingValue("SUFeedURL")
        }

        guard let releasePageURLString = bundle.object(forInfoDictionaryKey: "RCMMReleasePageURL") as? String else {
            throw AppBundleUpdateInfoError.missingValue("RCMMReleasePageURL")
        }

        guard let releasePageURL = URL(string: releasePageURLString) else {
            throw AppBundleUpdateInfoError.invalidValue("releasePageURL")
        }

        return AppBundleUpdateInfo(
            bundlePath: bundlePath,
            currentVersion: currentVersion,
            displayVersion: displayVersion,
            feedURL: feedURL,
            updatesEnabled: updatesEnabled,
            releasePageURL: releasePageURL
        )
    }

    private static func boolValue(
        forInfoDictionaryKey key: String,
        bundle: Bundle,
        fallback: Bool
    ) -> Bool {
        if let value = bundle.object(forInfoDictionaryKey: key) as? Bool {
            return value
        }

        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else {
            return fallback
        }

        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes":
            return true
        case "0", "false", "no":
            return false
        default:
            return fallback
        }
    }

    private static func urlValue(
        forInfoDictionaryKey key: String,
        bundle: Bundle
    ) throws -> URL? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else {
            return nil
        }
        guard let url = URL(string: trimmed) else {
            throw AppBundleUpdateInfoError.invalidValue(key)
        }
        return url
    }
}
