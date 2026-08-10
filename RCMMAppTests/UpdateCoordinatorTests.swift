import Foundation
import RCMMShared
import Testing
@testable import rcmm

@Suite("UpdateCoordinator", .serialized)
@MainActor
struct UpdateCoordinatorTests {
    private let feedURL = URL(string: "https://example.com/appcast.xml")!
    private let releaseURL = URL(string: "https://github.com/sunven/rcmm/releases")!

    @Test("禁用更新时展示下载入口且不启动安装器")
    func disabledUpdatesUseReleasePage() {
        var installFactoryCount = 0
        var openedURLs: [URL] = []
        let coordinator = makeCoordinator(
            bundleInfo: bundleInfo(updatesEnabled: false),
            openURL: { openedURLs.append($0) },
            makeInstallAction: {
                installFactoryCount += 1
                return {}
            }
        )

        #expect(coordinator.presentation.displayVersion == "1.2.3-dev.4")
        #expect(!coordinator.presentation.canCheck)
        #expect(coordinator.presentation.primaryActionTitle == "打开下载页")
        #expect(installFactoryCount == 0)

        coordinator.performPrimaryAction()
        #expect(openedURLs == [releaseURL])
    }

    @Test("手动检查发现可原地安装的新版本")
    func manualCheckInstallsAvailableUpdate() async {
        var installCount = 0
        let coordinator = makeCoordinator(
            bundleInfo: bundleInfo(),
            latestItem: latestItem(),
            makeInstallAction: {
                { installCount += 1 }
            }
        )

        coordinator.checkForUpdates()
        await coordinator.task?.value

        #expect(coordinator.presentation.primaryActionTitle == "立即更新")
        #expect(coordinator.presentation.statusText.contains("1.2.3-dev.10"))

        coordinator.performPrimaryAction()

        #expect(installCount == 1)
        #expect(coordinator.presentation.statusText == "正在准备安装 1.2.3-dev.10…")
        #expect(coordinator.presentation.primaryActionTitle == nil)
    }

    @Test("非标准安装路径会打开下载页")
    func manualInstallFallbackOpensReleasePage() async {
        var openedURLs: [URL] = []
        let coordinator = makeCoordinator(
            bundleInfo: bundleInfo(bundlePath: "/Volumes/rcmm/rcmm.app"),
            latestItem: latestItem(),
            openURL: { openedURLs.append($0) }
        )

        coordinator.checkForUpdates()
        await coordinator.task?.value

        #expect(coordinator.presentation.primaryActionTitle == "打开下载页")
        coordinator.performPrimaryAction()
        #expect(openedURLs == [releaseURL])
    }

    @Test("启动检查只调度一次并展示更新窗口")
    func startupCheckPresentsPromptOnce() async {
        var fetchCount = 0
        let windowCoordinator = WindowCoordinator(
            activateAsRegularApp: {},
            hideToMenuBar: {},
            visibleWindows: { [] }
        )
        let coordinator = UpdateCoordinator(
            windowCoordinator: windowCoordinator,
            loadBundleInfo: { bundleInfo() },
            fetchLatestItem: { _ in
                fetchCount += 1
                return latestItem()
            },
            openURL: { _ in },
            makeInstallAction: { {} },
            isDebugBuild: false,
            startupDelay: .zero
        )

        coordinator.scheduleStartupCheckIfNeeded()
        let startupTask = coordinator.task
        coordinator.scheduleStartupCheckIfNeeded()
        await startupTask?.value

        #expect(fetchCount == 1)
        #expect(windowCoordinator.hasWindow(.updatePrompt))
        #expect(coordinator.presentation.primaryActionTitle == "立即更新")

        windowCoordinator.dismiss(.updatePrompt, performCloseEffects: false)
    }

    private func makeCoordinator(
        bundleInfo: AppBundleUpdateInfo,
        latestItem: DevAppcastItem? = nil,
        openURL: @escaping @MainActor (URL) -> Void = { _ in },
        makeInstallAction: @escaping @MainActor () -> (@MainActor () -> Void) = { {} }
    ) -> UpdateCoordinator {
        UpdateCoordinator(
            windowCoordinator: WindowCoordinator(),
            loadBundleInfo: { bundleInfo },
            fetchLatestItem: { _ in
                guard let latestItem else {
                    throw TestError.missingLatestItem
                }
                return latestItem
            },
            openURL: openURL,
            makeInstallAction: makeInstallAction,
            isDebugBuild: true
        )
    }

    private func bundleInfo(
        bundlePath: String = "/Applications/rcmm.app",
        updatesEnabled: Bool = true
    ) -> AppBundleUpdateInfo {
        AppBundleUpdateInfo(
            bundlePath: bundlePath,
            currentVersion: DevBuildVersion(major: 1, minor: 2, patch: 3, build: 4),
            displayVersion: "1.2.3-dev.4",
            feedURL: updatesEnabled ? feedURL : nil,
            updatesEnabled: updatesEnabled,
            releasePageURL: releaseURL
        )
    }

    private func latestItem() -> DevAppcastItem {
        DevAppcastItem(
            version: DevBuildVersion(major: 1, minor: 2, patch: 3, build: 10),
            archiveURL: URL(string: "https://example.com/rcmm.zip")!,
            releaseNotesURL: URL(string: "https://example.com/notes")!,
            archiveLength: 123,
            signature: "signature"
        )
    }
}

private enum TestError: Error {
    case missingLatestItem
}
