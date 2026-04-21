import Foundation

public enum UpdateStartupDecision: Equatable, Sendable {
    case none
    case present(DevAppcastItem, UpdateInstallEligibility)
}

public enum UpdatePolicy {
    public static func installEligibility(
        bundlePath: String,
        releasePageURL: URL
    ) -> UpdateInstallEligibility {
        if bundlePath == "/Applications/rcmm.app" {
            return .inPlaceInstall
        }

        return .manualInstall(
            reason: "自动更新仅支持安装在 /Applications/rcmm.app 的开发版，请先重新安装到 Applications 后再更新。",
            fallbackURL: releasePageURL
        )
    }

    public static func startupDecision(
        latestItem: DevAppcastItem?,
        currentVersion: DevBuildVersion,
        bundlePath: String,
        dismissedDisplayVersion: String?,
        releasePageURL: URL
    ) -> UpdateStartupDecision {
        guard let latestItem else { return .none }
        guard latestItem.version > currentVersion else { return .none }
        guard latestItem.version.displayVersion != dismissedDisplayVersion else { return .none }

        return .present(
            latestItem,
            installEligibility(bundlePath: bundlePath, releasePageURL: releasePageURL)
        )
    }
}
