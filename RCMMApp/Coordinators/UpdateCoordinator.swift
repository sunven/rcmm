import AppKit
import Foundation
import Observation
import RCMMShared
import Sparkle
import SwiftUI

struct UpdatePresentation: Equatable {
    let displayVersion: String
    let statusText: String
    let canCheck: Bool
    let primaryActionTitle: String?
}

private enum AppUpdateState: Equatable {
    case idle
    case checking
    case current(lastCheckedAt: Date)
    case available(DevAppcastItem, UpdateInstallEligibility)
    case disabled(URL)
    case failed(String)
    case installing(DevAppcastItem)
}

/// 管理应用更新检查、安装动作和更新提示窗口。
@Observable
@MainActor
final class UpdateCoordinator {
    typealias InstallAction = @MainActor () -> Void

    var presentation: UpdatePresentation {
        let statusText: String
        let canCheck: Bool
        let primaryActionTitle: String?

        switch state {
        case .idle:
            statusText = "可以在这里手动检查更新。"
            canCheck = true
            primaryActionTitle = nil
        case .checking:
            statusText = "正在检查更新…"
            canCheck = true
            primaryActionTitle = nil
        case .current(let lastCheckedAt):
            statusText = "当前已是最新版本，上次检查时间：\(lastCheckedAt.formatted(date: .numeric, time: .shortened))"
            canCheck = true
            primaryActionTitle = nil
        case .available(let item, let eligibility):
            switch eligibility {
            case .inPlaceInstall:
                statusText = "发现新版本 \(item.displayVersion)，可以直接安装。"
            case .manualInstall(let reason, _):
                statusText = "发现新版本 \(item.displayVersion)。\(reason)"
            }
            canCheck = true
            primaryActionTitle = Self.primaryButtonTitle(for: eligibility)
        case .disabled:
            statusText = "这个构建暂未启用应用内更新，请从 Releases 页面下载新版。"
            canCheck = false
            primaryActionTitle = "打开下载页"
        case .failed(let message):
            statusText = message
            canCheck = true
            primaryActionTitle = nil
        case .installing(let item):
            statusText = "正在准备安装 \(item.displayVersion)…"
            canCheck = true
            primaryActionTitle = nil
        }

        return UpdatePresentation(
            displayVersion: currentDisplayVersion,
            statusText: statusText,
            canCheck: canCheck,
            primaryActionTitle: primaryActionTitle
        )
    }

    @ObservationIgnored private(set) var task: Task<Void, Never>?
    private var state: AppUpdateState = .idle
    private var currentDisplayVersion = "未知版本"
    @ObservationIgnored private var dismissedUpdateDisplayVersion: String?
    @ObservationIgnored private var hasScheduledStartupCheck = false
    @ObservationIgnored private var shouldHideToMenuBarAfterPromptCloses = true
    @ObservationIgnored private var installAction: InstallAction?

    private let windowCoordinator: WindowCoordinator
    private let loadBundleInfo: @MainActor () throws -> AppBundleUpdateInfo
    private let fetchLatestItem: @MainActor (URL) async throws -> DevAppcastItem
    private let openURL: @MainActor (URL) -> Void
    private let makeInstallAction: @MainActor () -> InstallAction
    private let now: @MainActor () -> Date
    private let isDebugBuild: Bool
    private let startupDelay: Duration

#if DEBUG
    private static let currentBuildIsDebug = true
#else
    private static let currentBuildIsDebug = false
#endif

    convenience init(
        windowCoordinator: WindowCoordinator,
        forPreview: Bool = false
    ) {
        let feedClient = UpdateFeedClient()
        self.init(
            windowCoordinator: windowCoordinator,
            forPreview: forPreview,
            loadBundleInfo: { try AppBundleUpdateInfo.current() },
            fetchLatestItem: { try await feedClient.fetchLatestItem(feedURL: $0) },
            openURL: { _ = NSWorkspace.shared.open($0) },
            makeInstallAction: {
                let updater = SPUStandardUpdaterController(
                    startingUpdater: true,
                    updaterDelegate: nil,
                    userDriverDelegate: nil
                )
                return { updater.checkForUpdates(nil) }
            },
            now: Date.init,
            isDebugBuild: Self.currentBuildIsDebug,
            startupDelay: .seconds(3)
        )
    }

    init(
        windowCoordinator: WindowCoordinator,
        forPreview: Bool = false,
        loadBundleInfo: @escaping @MainActor () throws -> AppBundleUpdateInfo,
        fetchLatestItem: @escaping @MainActor (URL) async throws -> DevAppcastItem,
        openURL: @escaping @MainActor (URL) -> Void,
        makeInstallAction: @escaping @MainActor () -> InstallAction,
        now: @escaping @MainActor () -> Date = Date.init,
        isDebugBuild: Bool,
        startupDelay: Duration = .seconds(3)
    ) {
        self.windowCoordinator = windowCoordinator
        self.loadBundleInfo = loadBundleInfo
        self.fetchLatestItem = fetchLatestItem
        self.openURL = openURL
        self.makeInstallAction = makeInstallAction
        self.now = now
        self.isDebugBuild = isDebugBuild
        self.startupDelay = startupDelay

        guard !forPreview else { return }

        var shouldStartUpdater = true
        if let bundleInfo = try? loadBundleInfo() {
            currentDisplayVersion = bundleInfo.displayVersion
            if !bundleInfo.updatesEnabled {
                state = .disabled(bundleInfo.releasePageURL)
                shouldStartUpdater = false
            }
        }
        if shouldStartUpdater {
            installAction = makeInstallAction()
        }
    }

    func checkForUpdates() {
        guard presentation.canCheck else { return }

        task = Task { [weak self] in
            await self?.performUpdateCheck(silent: false)
        }
    }

    func performPrimaryAction() {
        if case .disabled(let fallbackURL) = state {
            openURL(fallbackURL)
            return
        }

        guard case .available(let item, let eligibility) = state else { return }
        switch eligibility {
        case .inPlaceInstall:
            shouldHideToMenuBarAfterPromptCloses = false
            closeUpdatePromptWindow()
            state = .installing(item)
            installAction?()
        case .manualInstall(_, let fallbackURL):
            shouldHideToMenuBarAfterPromptCloses = true
            closeUpdatePromptWindow()
            openURL(fallbackURL)
        }
    }

    func scheduleStartupCheckIfNeeded() {
        guard !hasScheduledStartupCheck else { return }
        if let bundleInfo = try? loadBundleInfo(), !bundleInfo.updatesEnabled {
            return
        }
        guard UpdatePolicy.allowsStartupAutomaticCheck(isDebugBuild: isDebugBuild) else { return }
        hasScheduledStartupCheck = true

        task = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.startupDelay)
            await self.performStartupUpdateCheck()
        }
    }

    private func performUpdateCheck(silent: Bool) async {
        state = .checking

        do {
            let bundleInfo = try loadBundleInfo()
            currentDisplayVersion = bundleInfo.displayVersion
            guard bundleInfo.updatesEnabled, let feedURL = bundleInfo.feedURL else {
                state = .disabled(bundleInfo.releasePageURL)
                return
            }

            let latestItem = try await fetchLatestItem(feedURL)
            let eligibility = UpdatePolicy.installEligibility(
                bundlePath: bundleInfo.bundlePath,
                releasePageURL: bundleInfo.releasePageURL
            )

            if latestItem.version > bundleInfo.currentVersion {
                state = .available(latestItem, eligibility)
            } else if !silent {
                state = .current(lastCheckedAt: now())
            } else {
                state = .idle
            }
        } catch {
            state = .failed("检查更新失败：\(error.localizedDescription)")
        }
    }

    private func performStartupUpdateCheck() async {
        do {
            let bundleInfo = try loadBundleInfo()
            guard bundleInfo.updatesEnabled, let feedURL = bundleInfo.feedURL else {
                state = .disabled(bundleInfo.releasePageURL)
                return
            }

            let latestItem = try await fetchLatestItem(feedURL)
            let decision = UpdatePolicy.startupDecision(
                latestItem: latestItem,
                currentVersion: bundleInfo.currentVersion,
                bundlePath: bundleInfo.bundlePath,
                dismissedDisplayVersion: dismissedUpdateDisplayVersion,
                releasePageURL: bundleInfo.releasePageURL
            )

            switch decision {
            case .none:
                state = .idle
            case .present(let item, let eligibility):
                state = .available(item, eligibility)
                showUpdatePrompt(for: item, eligibility: eligibility)
            }
        } catch {
            state = .failed("检查更新失败：\(error.localizedDescription)")
        }
    }

    private static func primaryButtonTitle(for eligibility: UpdateInstallEligibility) -> String {
        switch eligibility {
        case .inPlaceInstall:
            return "立即更新"
        case .manualInstall:
            return "打开下载页"
        }
    }

    private func showUpdatePrompt(for item: DevAppcastItem, eligibility: UpdateInstallEligibility) {
        windowCoordinator.dismiss(.updatePrompt, performCloseEffects: false)
        shouldHideToMenuBarAfterPromptCloses = true

        let contentView = UpdatePromptView(
            version: item.displayVersion,
            releaseNotesURL: item.releaseNotesURL,
            primaryButtonTitle: Self.primaryButtonTitle(for: eligibility),
            onPrimaryAction: { [weak self] in
                self?.performPrimaryAction()
            },
            onLater: { [weak self] in
                self?.dismissAvailableUpdateForSession()
            }
        )

        windowCoordinator.present(.updatePrompt, content: contentView) { [weak self] _ in
            self?.handleUpdatePromptWindowClosed() ?? true
        }
    }

    private func dismissAvailableUpdateForSession() {
        if case .available(let item, _) = state {
            dismissedUpdateDisplayVersion = item.displayVersion
        }
        shouldHideToMenuBarAfterPromptCloses = true
        closeUpdatePromptWindow()
    }

    private func closeUpdatePromptWindow() {
        windowCoordinator.dismiss(.updatePrompt)
    }

    private func handleUpdatePromptWindowClosed() -> Bool {
        let shouldHideToMenuBar = shouldHideToMenuBarAfterPromptCloses
        shouldHideToMenuBarAfterPromptCloses = true
        return shouldHideToMenuBar
    }
}
