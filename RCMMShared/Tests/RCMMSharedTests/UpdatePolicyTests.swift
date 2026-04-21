import Foundation
import Testing
@testable import RCMMShared

@Suite("UpdatePolicy 测试")
struct UpdatePolicyTests {
    let releaseURL = URL(string: "https://github.com/sunven/rcmm/releases")!

    @Test("只有 /Applications/rcmm.app 允许原地安装")
    func applicationsBundleIsEligible() {
        let result = UpdatePolicy.installEligibility(
            bundlePath: "/Applications/rcmm.app",
            releasePageURL: releaseURL
        )
        #expect(result == .inPlaceInstall)
    }

    @Test("挂载卷中的 app 会降级为人工安装")
    func mountedVolumeFallsBackToManualInstall() {
        let result = UpdatePolicy.installEligibility(
            bundlePath: "/Volumes/rcmm/rcmm.app",
            releasePageURL: releaseURL
        )

        switch result {
        case .manualInstall(let reason, let fallbackURL):
            #expect(reason.contains("/Applications/rcmm.app"))
            #expect(fallbackURL == releaseURL)
        default:
            Issue.record("Expected manualInstall")
        }
    }

    @Test("同一次运行中点过稍后，不再重复弹同版本提示")
    func suppressDismissedVersion() {
        let latest = DevAppcastItem(
            version: DevBuildVersion(major: 1, minor: 2, patch: 3, build: 10),
            archiveURL: URL(string: "https://example.com/rcmm.zip")!,
            releaseNotesURL: URL(string: "https://example.com/notes")!,
            archiveLength: 67890,
            signature: "sig-10"
        )

        let decision = UpdatePolicy.startupDecision(
            latestItem: latest,
            currentVersion: DevBuildVersion(major: 1, minor: 2, patch: 3, build: 4),
            bundlePath: "/Applications/rcmm.app",
            dismissedDisplayVersion: "1.2.3-dev.10",
            releasePageURL: releaseURL
        )

        #expect(decision == .none)
    }
}
