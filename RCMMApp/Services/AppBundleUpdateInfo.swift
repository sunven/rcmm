import Foundation
import RCMMShared

enum AppBundleUpdateInfoError: Error {
    case missingValue(String)
    case invalidValue(String)
}

struct AppBundleUpdateInfo: Sendable {
    let bundlePath: String
    let currentVersion: DevBuildVersion
    let displayVersion: String
    let feedURL: URL
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

        guard
            let feedURLString = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            let feedURL = URL(string: feedURLString)
        else {
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
            releasePageURL: releasePageURL
        )
    }
}
