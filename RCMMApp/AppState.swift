import Foundation
import os.log
import RCMMShared
import Sparkle
import SwiftUI

enum AppUpdateState: Equatable {
    case idle
    case checking
    case current(lastCheckedAt: Date)
    case available(DevAppcastItem, UpdateInstallEligibility)
    case disabled(URL)
    case failed(String)
    case installing(DevAppcastItem)
}

enum ExtensionCleanupFlowState: Equatable {
    case idle
    case planning
    case review(ExtensionCleanupPlan)
    case running(ExtensionCleanupStep)
    case finished(ExtensionCleanupResult)
}

@Observable
@MainActor
final class AppState {
    // MARK: - 领域模型（委托给 AppCoordinator）

    private let coordinator: AppCoordinator

    var menuEntries: [MenuEntry] {
        get { coordinator.configStore.menuEntries }
        set { coordinator.configStore.menuEntries = newValue }
    }

    var menuPresentationMode: MenuPresentationMode {
        get { coordinator.configStore.menuPresentationMode }
        set { coordinator.configStore.menuPresentationMode = newValue }
    }

    var scriptPublishStates: [String: ScriptPublishState] {
        get { coordinator.configStore.scriptPublishStates }
    }

    var errorRecords: [ErrorRecord] {
        get { coordinator.configStore.errorRecords }
    }

    var autoRepairMessage: String? {
        get { coordinator.autoRepairMessage }
    }

    // MARK: - UI 状态（AppState 保留）

    var discoveredApps: [AppInfo] = []
    var compositePresetMessage: String? = nil
    var popoverState: PopoverState = .normal
    var extensionStatus: ExtensionStatus = .unknown
    var extensionStatusDetail: String? = nil
    var currentDisplayVersion = "未知版本"
    var updateState: AppUpdateState = .idle
    var isShowingExtensionCleanupSheet = false
    var extensionCleanupFlowState: ExtensionCleanupFlowState = .idle

    var isOnboardingCompleted: Bool {
        didSet {
            SharedPreferencesStore()
                .set(isOnboardingCompleted, forKey: SharedKeys.onboardingCompleted)
        }
    }

    private var onboardingWindow: NSWindow?
    private var windowCloseObserver: Any?

    private var healthCheckTimer: Timer?
    private let healthCheckInterval: TimeInterval = 1800 // 30 分钟

    @ObservationIgnored private var updatePromptWindow: NSWindow?
    @ObservationIgnored private var updatePromptCloseObserver: Any?
    @ObservationIgnored private var dismissedUpdateDisplayVersion: String?
    @ObservationIgnored private var hasScheduledStartupUpdateCheck = false
    @ObservationIgnored private var shouldHideToMenuBarAfterUpdatePromptCloses = true
    @ObservationIgnored private var sparkleUpdater: SPUStandardUpdaterController?
    @ObservationIgnored private let updateFeedClient = UpdateFeedClient()
    @ObservationIgnored private let extensionCleanupService = ExtensionCleanupService()
    @ObservationIgnored private var extensionCleanupPlanningRequestID: UInt64 = 0
    @ObservationIgnored private var extensionCleanupExecutionRequestID: UInt64 = 0
    @ObservationIgnored private var extensionCleanupWindow: NSWindow?
    @ObservationIgnored private var extensionCleanupWindowCloseObserver: Any?

    private let logger = Logger(
        subsystem: "com.sunven.rcmm",
        category: "appState"
    )

#if DEBUG
    private static let isDebugBuild = true
#else
    private static let isDebugBuild = false
#endif

    init(coordinator: AppCoordinator? = nil, forPreview: Bool = false) {
        self.coordinator = coordinator ?? AppCoordinator(forPreview: forPreview)
        isOnboardingCompleted = SharedPreferencesStore()
            .bool(forKey: SharedKeys.onboardingCompleted)

        guard !forPreview else { return }

        var shouldStartSparkleUpdater = true
        if let bundleInfo = try? AppBundleUpdateInfo.current() {
            currentDisplayVersion = bundleInfo.displayVersion
            if !bundleInfo.updatesEnabled {
                updateState = .disabled(bundleInfo.releasePageURL)
                shouldStartSparkleUpdater = false
            }
        }
        if shouldStartSparkleUpdater {
            sparkleUpdater = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        }

        checkExtensionStatus()
        startHealthMonitoring()

        if !isOnboardingCompleted {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                self.showOnboardingIfNeeded()
            }
        } else {
            scheduleStartupUpdateCheckIfNeeded()
        }
    }

    // MARK: - Error Queue

    func loadErrors() {
        // 委托给 AppCoordinator：configStore 负责加载错误，coordinator 负责触发自动修复
        coordinator.configStore.loadErrors()
    }

    func dismissAllErrors() {
        coordinator.dismissAllErrors()
    }

    // MARK: - Extension Status

    /// 检测 Finder 扩展状态，仅在状态变化时更新 extensionStatus 和 popoverState
    func checkExtensionStatus() {
        let report = PluginKitService.healthReport()
        let newStatus = report.status
        let newDetail = PluginKitService.detailMessage(for: report)
        let oldStatus = extensionStatus

        guard oldStatus != newStatus || extensionStatusDetail != newDetail else { return }

        extensionStatus = newStatus
        extensionStatusDetail = newDetail

        switch newStatus {
        case .enabled:
            popoverState = .normal
        case .otherBuildEnabled, .otherInstallationEnabled:
            popoverState = .healthWarning
        case .disabled:
            popoverState = .healthWarning
        case .unknown:
            popoverState = .normal
        }

        logger.info("Extension 状态变化: \(oldStatus.rawValue) → \(newStatus.rawValue), popoverState: \(String(describing: self.popoverState))")
    }

    func activateCurrentFinderExtension() async throws {
        try await Task.detached(priority: .userInitiated) {
            try PluginKitService.activateCurrent()
        }.value
        try? await Task.sleep(for: .milliseconds(300))
        checkExtensionStatus()
    }

    // MARK: - Extension Cleanup

    func beginExtensionCleanup() {
        if let window = extensionCleanupWindow {
            ActivationPolicyManager.activateAsRegularApp()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }
        guard case .idle = extensionCleanupFlowState else { return }

        extensionCleanupPlanningRequestID &+= 1
        let requestID = extensionCleanupPlanningRequestID
        showExtensionCleanupWindowIfNeeded()
        isShowingExtensionCleanupSheet = true
        extensionCleanupFlowState = .planning

        let cleanupService = extensionCleanupService
        logger.info("开始扫描旧扩展副本 (requestID=\(requestID))")
        Task { [weak self] in
            guard let self else { return }

            let plan = await Task.detached(priority: .userInitiated) {
                cleanupService.preparePlan(bundle: .main)
            }.value

            logger.info("扫描完成，准备切换到 review 状态 (requestID=\(requestID), planningID=\(self.extensionCleanupPlanningRequestID), sheet=\(self.isShowingExtensionCleanupSheet), state=\(String(describing: self.extensionCleanupFlowState)))")

            guard self.extensionCleanupPlanningRequestID == requestID else {
                logger.warning("扫描完成但 requestID 已过期，丢弃结果 (expected=\(requestID), current=\(self.extensionCleanupPlanningRequestID))")
                return
            }
            guard self.isShowingExtensionCleanupSheet else {
                logger.warning("扫描完成但 sheet 已关闭，丢弃结果")
                return
            }
            guard case .planning = self.extensionCleanupFlowState else {
                logger.warning("扫描完成但状态已不是 planning，丢弃结果 (state=\(String(describing: self.extensionCleanupFlowState)))")
                return
            }
            self.extensionCleanupFlowState = .review(plan)
            logger.info("已切换到 review 状态")
        }
    }

    func confirmExtensionCleanup(plan: ExtensionCleanupPlan) {
        guard isShowingExtensionCleanupSheet else { return }
        guard case .review(let currentPlan) = extensionCleanupFlowState else { return }
        guard currentPlan == plan else { return }

        extensionCleanupExecutionRequestID &+= 1
        let executionRequestID = extensionCleanupExecutionRequestID
        extensionCleanupFlowState = .running(.terminateProcesses)
        let cleanupService = extensionCleanupService

        Task { [weak self] in
            guard let self else { return }

            let result = await Task.detached(priority: .userInitiated) {
                cleanupService.execute(plan: plan) { step in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        guard self.extensionCleanupExecutionRequestID == executionRequestID else { return }
                        guard self.isShowingExtensionCleanupSheet else { return }
                        guard case .running = self.extensionCleanupFlowState else { return }
                        self.extensionCleanupFlowState = .running(step)
                    }
                }
            }.value

            self.checkExtensionStatus()
            guard self.extensionCleanupExecutionRequestID == executionRequestID else { return }
            guard self.isShowingExtensionCleanupSheet else { return }
            guard case .running = self.extensionCleanupFlowState else { return }
            self.extensionCleanupFlowState = .finished(result)
        }
    }

    func dismissExtensionCleanupSheet() {
        if case .running = extensionCleanupFlowState {
            return
        }
        extensionCleanupPlanningRequestID &+= 1
        extensionCleanupExecutionRequestID &+= 1
        closeExtensionCleanupWindow()
    }

    private func showExtensionCleanupWindowIfNeeded() {
        guard extensionCleanupWindow == nil else { return }

        let contentView = ExtensionCleanupSheet()
            .environment(self)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 460),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: contentView)
        window.title = "清理旧扩展副本"
        window.center()
        window.minSize = NSSize(width: 540, height: 360)

        extensionCleanupWindowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            Task { @MainActor in
                guard let self else { return }
                self.handleExtensionCleanupWindowClosed(window)
            }
        }

        extensionCleanupWindow = window
        ActivationPolicyManager.activateAsRegularApp()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func closeExtensionCleanupWindow() {
        guard let window = extensionCleanupWindow else {
            resetExtensionCleanupPresentationState()
            return
        }
        window.close()
    }

    private func handleExtensionCleanupWindowClosed(_ window: NSWindow?) {
        if let observer = extensionCleanupWindowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            extensionCleanupWindowCloseObserver = nil
        }
        if extensionCleanupWindow === window {
            extensionCleanupWindow = nil
        }
        resetExtensionCleanupPresentationState()

        guard let window else {
            ActivationPolicyManager.hideToMenuBar()
            return
        }
        guard !hasVisibleWindow(excluding: window) else { return }
        ActivationPolicyManager.hideToMenuBar()
    }

    private func resetExtensionCleanupPresentationState() {
        isShowingExtensionCleanupSheet = false
        extensionCleanupFlowState = .idle
    }

    /// 启动定期健康监控（每 30 分钟检测一次）
    private func startHealthMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(
            withTimeInterval: healthCheckInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkExtensionStatus()
            }
        }
    }

    /// 停止定期健康监控
    private func stopHealthMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    // MARK: - Updates

    var updateStatusText: String {
        switch updateState {
        case .idle:
            return "可以在这里手动检查更新。"
        case .checking:
            return "正在检查更新…"
        case .current(let lastCheckedAt):
            return "当前已是最新版本，上次检查时间：\(lastCheckedAt.formatted(date: .numeric, time: .shortened))"
        case .available(let item, let eligibility):
            switch eligibility {
            case .inPlaceInstall:
                return "发现新版本 \(item.displayVersion)，可以直接安装。"
            case .manualInstall(let reason, _):
                return "发现新版本 \(item.displayVersion)。\(reason)"
            }
        case .disabled:
            return "这个构建暂未启用应用内更新，请从 Releases 页面下载新版。"
        case .failed(let message):
            return message
        case .installing(let item):
            return "正在准备安装 \(item.displayVersion)…"
        }
    }

    var canCheckForUpdates: Bool {
        if case .disabled = updateState {
            return false
        }
        return true
    }

    var canPerformUpdatePrimaryAction: Bool {
        if case .available = updateState {
            return true
        }
        if case .disabled = updateState {
            return true
        }
        return false
    }

    var updatePrimaryActionTitle: String {
        if case .disabled = updateState {
            return "打开下载页"
        }

        guard case .available(_, let eligibility) = updateState else {
            return "检查更新"
        }

        return Self.primaryButtonTitle(for: eligibility)
    }

    private static func primaryButtonTitle(for eligibility: UpdateInstallEligibility) -> String {
        switch eligibility {
        case .inPlaceInstall:
            return "立即更新"
        case .manualInstall:
            return "打开下载页"
        }
    }

    func checkForUpdatesManually() {
        guard canCheckForUpdates else { return }

        Task {
            await performUpdateCheck(silent: false)
        }
    }

    func performUpdatePrimaryAction() {
        if case .disabled(let fallbackURL) = updateState {
            NSWorkspace.shared.open(fallbackURL)
            return
        }

        guard case .available(let item, let eligibility) = updateState else { return }
        switch eligibility {
        case .inPlaceInstall:
            shouldHideToMenuBarAfterUpdatePromptCloses = false
            closeUpdatePromptWindow()
            updateState = .installing(item)
            sparkleUpdater?.checkForUpdates(nil)
        case .manualInstall(_, let fallbackURL):
            shouldHideToMenuBarAfterUpdatePromptCloses = true
            closeUpdatePromptWindow()
            NSWorkspace.shared.open(fallbackURL)
        }
    }

    private func performUpdateCheck(silent: Bool) async {
        updateState = .checking

        do {
            let bundleInfo = try AppBundleUpdateInfo.current()
            currentDisplayVersion = bundleInfo.displayVersion
            guard bundleInfo.updatesEnabled, let feedURL = bundleInfo.feedURL else {
                updateState = .disabled(bundleInfo.releasePageURL)
                return
            }

            let latestItem = try await updateFeedClient.fetchLatestItem(feedURL: feedURL)
            let eligibility = UpdatePolicy.installEligibility(
                bundlePath: bundleInfo.bundlePath,
                releasePageURL: bundleInfo.releasePageURL
            )

            if latestItem.version > bundleInfo.currentVersion {
                updateState = .available(latestItem, eligibility)
            } else if !silent {
                updateState = .current(lastCheckedAt: Date())
            } else {
                updateState = .idle
            }
        } catch {
            updateState = .failed("检查更新失败：\(error.localizedDescription)")
        }
    }

    private func scheduleStartupUpdateCheckIfNeeded() {
        guard !hasScheduledStartupUpdateCheck, isOnboardingCompleted else { return }
        if let bundleInfo = try? AppBundleUpdateInfo.current(), !bundleInfo.updatesEnabled {
            return
        }
        guard UpdatePolicy.allowsStartupAutomaticCheck(isDebugBuild: Self.isDebugBuild) else { return }
        hasScheduledStartupUpdateCheck = true

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            await performStartupUpdateCheck()
        }
    }

    private func performStartupUpdateCheck() async {
        do {
            let bundleInfo = try AppBundleUpdateInfo.current()
            guard bundleInfo.updatesEnabled, let feedURL = bundleInfo.feedURL else {
                updateState = .disabled(bundleInfo.releasePageURL)
                return
            }

            let latestItem = try await updateFeedClient.fetchLatestItem(feedURL: feedURL)
            let decision = UpdatePolicy.startupDecision(
                latestItem: latestItem,
                currentVersion: bundleInfo.currentVersion,
                bundlePath: bundleInfo.bundlePath,
                dismissedDisplayVersion: dismissedUpdateDisplayVersion,
                releasePageURL: bundleInfo.releasePageURL
            )

            switch decision {
            case .none:
                updateState = .idle
            case .present(let item, let eligibility):
                updateState = .available(item, eligibility)
                showUpdatePrompt(for: item, eligibility: eligibility)
            }
        } catch {
            updateState = .failed("检查更新失败：\(error.localizedDescription)")
        }
    }

    private func showUpdatePrompt(for item: DevAppcastItem, eligibility: UpdateInstallEligibility) {
        replaceExistingUpdatePromptWindow()
        ActivationPolicyManager.activateAsRegularApp()
        shouldHideToMenuBarAfterUpdatePromptCloses = true

        let primaryButtonTitle = Self.primaryButtonTitle(for: eligibility)

        let contentView = UpdatePromptView(
            version: item.displayVersion,
            releaseNotesURL: item.releaseNotesURL,
            primaryButtonTitle: primaryButtonTitle,
            onPrimaryAction: { [weak self] in
                self?.performUpdatePrimaryAction()
            },
            onLater: { [weak self] in
                self?.dismissAvailableUpdateForSession()
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.title = "发现新版本"
        updatePromptCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            Task { @MainActor in
                guard let self, let window else { return }
                self.handleUpdatePromptWindowClosed(window)
            }
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        updatePromptWindow = window
    }

    func dismissAvailableUpdateForSession() {
        if case .available(let item, _) = updateState {
            dismissedUpdateDisplayVersion = item.displayVersion
        }
        shouldHideToMenuBarAfterUpdatePromptCloses = true
        closeUpdatePromptWindow()
    }

    private func replaceExistingUpdatePromptWindow() {
        guard let window = updatePromptWindow else { return }
        if let observer = updatePromptCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            updatePromptCloseObserver = nil
        }
        updatePromptWindow = nil
        window.close()
    }

    private func closeUpdatePromptWindow() {
        updatePromptWindow?.close()
    }

    private func handleUpdatePromptWindowClosed(_ window: NSWindow) {
        if let observer = updatePromptCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            updatePromptCloseObserver = nil
        }
        if updatePromptWindow === window {
            updatePromptWindow = nil
        }

        let shouldHideToMenuBar = shouldHideToMenuBarAfterUpdatePromptCloses
        shouldHideToMenuBarAfterUpdatePromptCloses = true

        guard shouldHideToMenuBar else { return }
        guard !hasVisibleWindow(excluding: window) else { return }
        ActivationPolicyManager.hideToMenuBar()
    }

    private func hasVisibleWindow(excluding excludedWindow: NSWindow) -> Bool {
        NSApp.windows.contains { window in
            window !== excludedWindow && window.isVisible
        }
    }

    // MARK: - Onboarding Window

    func showOnboardingIfNeeded() {
        guard !isOnboardingCompleted else { return }
        showOnboarding()
    }

    func showOnboarding() {
        if let window = onboardingWindow {
            ActivationPolicyManager.activateAsRegularApp()
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        let contentView = OnboardingFlowView()
            .environment(self)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.title = "欢迎使用 rcmm"
        window.center()
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 480, height: 500))
        window.minSize = NSSize(width: 480, height: 500)
        window.maxSize = NSSize(width: 480, height: 500)

        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            Task { @MainActor in
                self?.handleOnboardingWindowClosed(window)
            }
        }

        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)

        ActivationPolicyManager.activateAsRegularApp()
    }

    func closeOnboarding() {
        guard let window = onboardingWindow else {
            scheduleStartupUpdateCheckIfNeeded()
            return
        }
        window.close()
        scheduleStartupUpdateCheckIfNeeded()
    }

    private func handleOnboardingWindowClosed(_ window: NSWindow?) {
        if let observer = windowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            windowCloseObserver = nil
        }
        if onboardingWindow === window {
            onboardingWindow = nil
        }

        guard let window else {
            ActivationPolicyManager.hideToMenuBar()
            return
        }
        guard !hasVisibleWindow(excluding: window) else { return }
        ActivationPolicyManager.hideToMenuBar()
    }

    // MARK: - Menu Items

    var primaryNewFileMenu: NewFileMenuConfig? {
        coordinator.configStore.primaryNewFileMenu
    }

    @discardableResult
    func ensureNewFileMenu() -> UUID {
        coordinator.configStore.ensureNewFileMenu()
    }

    /// 从 AppInfo 创建 MenuItemConfig 并添加到菜单
    @discardableResult
    func addMenuItem(from appInfo: AppInfo) -> UUID? {
        coordinator.addMenuItem(from: appInfo)
    }

    @discardableResult
    func addEmptyCompositeCommand() -> UUID {
        coordinator.addEmptyCompositeCommand()
    }

    @discardableResult
    func addGitPullCommand() -> UUID {
        coordinator.addGitPullCommand()
    }

    func addEditorTerminalPreset(onCreated: ((UUID) -> Void)? = nil) {
        compositePresetMessage = "正在查找已安装的编辑器和终端…"

        if discoveredApps.isEmpty {
            let discoveryService = AppDiscoveryService()
            Task { [weak self] in
                let apps = await Task.detached {
                    discoveryService.scanApplications()
                }.value
                await MainActor.run {
                    guard let self else { return }
                    self.discoveredApps = apps
                    self.createEditorTerminalPresetFromDiscoveredApps(onCreated: onCreated)
                }
            }
        } else {
            createEditorTerminalPresetFromDiscoveredApps(onCreated: onCreated)
        }
    }

    private func createEditorTerminalPresetFromDiscoveredApps(onCreated: ((UUID) -> Void)? = nil) {
        guard let editor = preferredDiscoveredApp(
            in: .editor,
            preferredBundleIds: ["com.microsoft.VSCode"]
        ),
              let terminal = preferredDiscoveredApp(
                in: .terminal,
                preferredBundleIds: ["com.apple.Terminal"]
              ) else {
            compositePresetMessage = "未找到可用的编辑器和终端，请先安装或通过添加应用确认扫描结果"
            return
        }

        let composite = CompositeMenuItemConfig(
            name: "VS Code + Terminal",
            iconName: "rectangle.split.2x1",
            steps: [
                CompositeCommandStep(
                    kind: .app,
                    name: editor.name,
                    commandTemplate: preferredCommandTemplate(for: editor),
                    appPath: editor.path,
                    bundleId: editor.bundleId
                ),
                CompositeCommandStep(
                    kind: .app,
                    name: terminal.name,
                    commandTemplate: "open -a {app} {path}",
                    appPath: terminal.path,
                    bundleId: terminal.bundleId
                ),
            ]
        )
        let id = coordinator.addCompositeCommand(composite)
        compositePresetMessage = nil
        onCreated?(id)
    }

    /// 批量添加多个应用到菜单（只触发一次 saveAndSync）
    @discardableResult
    func addMenuItems(from appInfos: [AppInfo]) -> [UUID] {
        coordinator.addMenuItems(from: appInfos)
    }

    private func preferredDiscoveredApp(
        in category: AppCategory,
        preferredBundleIds: [String]
    ) -> AppInfo? {
        for bundleId in preferredBundleIds {
            if let match = discoveredApps.first(where: { $0.category == category && $0.bundleId == bundleId }) {
                return match
            }
        }
        return discoveredApps.first { $0.category == category }
    }

    private func preferredCommandTemplate(for appInfo: AppInfo) -> String {
        if appInfo.bundleId == "com.microsoft.VSCode" {
            return CompositeCommandTemplates.vsCodeCLI
        }

        return CompositeCommandTemplates.legacyOpenApp
    }

    /// 移动菜单项到新位置（拖拽排序）
    func moveEntry(from source: IndexSet, to destination: Int, sync: Bool = true) {
        if sync {
            coordinator.moveEntry(from: source, to: destination)
        } else {
            coordinator.configStore.moveEntry(from: source, to: destination, save: false)
        }
    }

    /// 删除指定位置的菜单项
    func removeEntry(at offsets: IndexSet) {
        coordinator.removeEntry(at: offsets)
    }

    func updateNewFileMenuName(for menuID: UUID, name: String) {
        coordinator.updateNewFileMenuName(for: menuID, name: name)
    }

    func addNewFileTemplate(to menuID: UUID) {
        coordinator.addNewFileTemplate(to: menuID)
    }

    func updateNewFileTemplate(
        menuID: UUID,
        templateID: UUID,
        displayName: String,
        baseName: String,
        fileExtension: String,
        creationMode: NewFileCreationMode,
        templatePath: String?,
        initialContent: String?,
        isEnabled: Bool
    ) {
        coordinator.updateNewFileTemplate(
            menuID: menuID,
            templateID: templateID,
            displayName: displayName,
            baseName: baseName,
            fileExtension: fileExtension,
            creationMode: creationMode,
            templatePath: templatePath,
            initialContent: initialContent,
            isEnabled: isEnabled
        )
    }

    func removeNewFileTemplate(menuID: UUID, templateID: UUID) {
        coordinator.removeNewFileTemplate(menuID: menuID, templateID: templateID)
    }

    func moveNewFileTemplate(menuID: UUID, from source: IndexSet, to destination: Int) {
        coordinator.moveNewFileTemplate(menuID: menuID, from: source, to: destination)
    }

    func updateCustomCommand(
        for itemId: UUID,
        name: String? = nil,
        command: String?,
        executionMode: CustomCommandExecutionMode? = nil
    ) {
        coordinator.updateCustomCommand(
            for: itemId,
            name: name,
            command: command,
            executionMode: executionMode
        )
    }

    func updateCompositeName(for compositeId: UUID, name: String) {
        coordinator.updateCompositeName(for: compositeId, name: name)
    }

    func updateCompositeStep(
        compositeId: UUID,
        stepId: UUID,
        name: String,
        commandTemplate: String,
        appPath: String?,
        bundleId: String?,
        isEnabled: Bool
    ) {
        coordinator.updateCompositeStep(
            compositeID: compositeId,
            stepID: stepId,
            name: name,
            commandTemplate: commandTemplate,
            appPath: appPath,
            bundleID: bundleId,
            isEnabled: isEnabled
        )
    }

    func addShellStep(to compositeId: UUID) {
        coordinator.addShellStep(to: compositeId)
    }

    func removeCompositeStep(compositeId: UUID, stepId: UUID) {
        coordinator.removeCompositeStep(compositeID: compositeId, stepID: stepId)
    }

    func moveCompositeStep(compositeId: UUID, from source: IndexSet, to destination: Int) {
        coordinator.moveCompositeStep(compositeID: compositeId, from: source, to: destination)
    }

    /// 切换菜单项的启用/禁用状态
    func toggleEntry(for entryId: String, isEnabled: Bool) {
        coordinator.toggleEntry(for: entryId, isEnabled: isEnabled)
    }

    func updateMenuPresentationMode(_ mode: MenuPresentationMode) {
        coordinator.updateMenuPresentationMode(mode)
    }

    /// 保存配置 + 同步脚本 + 发送 Darwin Notification
    func saveAndSync() {
        coordinator.saveAndSync()
    }

}
