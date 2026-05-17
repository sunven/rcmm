import Foundation
import os.log
import RCMMShared
import SwiftUI

enum AppUpdateState: Equatable {
    case idle
    case checking
    case current(lastCheckedAt: Date)
    case available(DevAppcastItem, UpdateInstallEligibility)
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
    var menuEntries: [MenuEntry] = []
    var menuPresentationMode: MenuPresentationMode = .flat
    var discoveredApps: [AppInfo] = []
    var compositePresetMessage: String? = nil
    var scriptPublishStates: [String: ScriptPublishState] = [:]
    var popoverState: PopoverState = .normal
    var extensionStatus: ExtensionStatus = .unknown
    var extensionStatusDetail: String? = nil
    var errorRecords: [ErrorRecord] = []
    var autoRepairMessage: String? = nil
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
    @ObservationIgnored private var sparkleUpdater: SparkleUpdaterService?
    @ObservationIgnored private let updateFeedClient = UpdateFeedClient()
    @ObservationIgnored private let extensionCleanupService = ExtensionCleanupService()
    @ObservationIgnored private var extensionCleanupPlanningRequestID: UInt64 = 0
    @ObservationIgnored private var extensionCleanupExecutionRequestID: UInt64 = 0
    @ObservationIgnored private var extensionCleanupWindow: NSWindow?
    @ObservationIgnored private var extensionCleanupWindowCloseObserver: Any?
    private let configService = SharedConfigService()
    private let errorQueue = SharedErrorQueue()
    private let publishStore = ScriptPublishStore()
    private var hasTriggeredAutoRepair = false
    private let logger = Logger(
        subsystem: "com.sunven.rcmm",
        category: "appState"
    )

#if DEBUG
    private static let isDebugBuild = true
#else
    private static let isDebugBuild = false
#endif

    init(forPreview: Bool = false) {
        isOnboardingCompleted = SharedPreferencesStore()
            .bool(forKey: SharedKeys.onboardingCompleted)

        guard !forPreview else { return }

        if let bundleInfo = try? AppBundleUpdateInfo.current() {
            currentDisplayVersion = bundleInfo.displayVersion
        }
        sparkleUpdater = SparkleUpdaterService()

        loadMenuPresentationMode()
        loadMenuEntries()
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
        errorRecords = errorQueue.loadAll()

        guard !hasTriggeredAutoRepair else { return }

        let hasScriptFileErrors = errorRecords.contains { record in
            record.message.contains("脚本文件不存在") || record.message.contains("脚本文件无法加载")
        }
        if hasScriptFileErrors {
            hasTriggeredAutoRepair = true
            autoRepairMessage = "正在自动修复脚本文件…"

            let entries = menuEntries
            Self.syncQueue.async { [weak self] in
                let installer = ScriptInstallerService()
                let results = installer.syncScripts(with: entries)
                DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
                Task { @MainActor in
                    guard let self else { return }
                    let repairedNames = Set(
                        results
                            .filter { $0.status == .current }
                            .map(\.displayName)
                    )
                    if !repairedNames.isEmpty {
                        self.errorQueue.removeAll { record in
                            repairedNames.contains(record.context ?? "")
                                && (
                                    record.message.contains("脚本文件不存在")
                                        || record.message.contains("脚本文件无法加载")
                                )
                        }
                    }
                    self.errorRecords = self.errorQueue.loadAll()
                    let didPublishAny = results.contains { $0.status == .current }
                    self.autoRepairMessage = didPublishAny ? "已自动修复脚本文件" : "自动修复失败，请打开设置检查"
                }
            }
        }
    }

    func dismissAllErrors() {
        errorQueue.removeAll()
        errorRecords = []
        hasTriggeredAutoRepair = false
        autoRepairMessage = nil
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
        case .otherInstallationEnabled:
            popoverState = .healthWarning
        case .disabled:
            popoverState = .healthWarning
        case .unknown:
            popoverState = .normal
        }

        logger.info("Extension 状态变化: \(oldStatus.rawValue) → \(newStatus.rawValue), popoverState: \(String(describing: self.popoverState))")
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
                return "发现新版本 \(item.version.displayVersion)，可以直接安装。"
            case .manualInstall(let reason, _):
                return "发现新版本 \(item.version.displayVersion)。\(reason)"
            }
        case .failed(let message):
            return message
        case .installing(let item):
            return "正在准备安装 \(item.version.displayVersion)…"
        }
    }

    var canPerformUpdatePrimaryAction: Bool {
        if case .available = updateState {
            return true
        }
        return false
    }

    var updatePrimaryActionTitle: String {
        guard case .available(_, let eligibility) = updateState else {
            return "检查更新"
        }

        switch eligibility {
        case .inPlaceInstall:
            return "立即更新"
        case .manualInstall:
            return "打开下载页"
        }
    }

    func checkForUpdatesManually() {
        Task {
            await performUpdateCheck(silent: false)
        }
    }

    func performUpdatePrimaryAction() {
        guard case .available(let item, let eligibility) = updateState else { return }
        switch eligibility {
        case .inPlaceInstall:
            shouldHideToMenuBarAfterUpdatePromptCloses = false
            closeUpdatePromptWindow()
            updateState = .installing(item)
            sparkleUpdater?.beginInteractiveUpdate()
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

            let latestItem = try await updateFeedClient.fetchLatestItem(feedURL: bundleInfo.feedURL)
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
            let latestItem = try await updateFeedClient.fetchLatestItem(feedURL: bundleInfo.feedURL)
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

        let primaryButtonTitle: String
        switch eligibility {
        case .inPlaceInstall:
            primaryButtonTitle = "立即更新"
        case .manualInstall:
            primaryButtonTitle = "打开下载页"
        }

        let contentView = UpdatePromptView(
            version: item.version.displayVersion,
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
            dismissedUpdateDisplayVersion = item.version.displayVersion
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

    func loadMenuPresentationMode() {
        menuPresentationMode = configService.loadMenuPresentationMode()
    }

    /// 从 SharedConfigService 加载已配置菜单项；首次启动时创建默认 Terminal 配置
    ///
    /// 注意: 每次启动都调用 syncScriptsInBackground() 是有意为之，确保脚本文件
    /// 与配置保持一致（防止脚本被手动删除或损坏的情况）。
    /// 优化建议: 未来可改为仅校验脚本文件是否存在，而非每次都重新编译。
    func loadMenuEntries() {
        let existing = migrateCompositeCommandTemplatesIfNeeded(configService.loadEntries())
        scriptPublishStates = publishStore.loadAll()

        if existing.isEmpty {
            let terminalConfig = MenuItemConfig(
                appName: "Terminal",
                bundleId: "com.apple.Terminal",
                appPath: "/System/Applications/Utilities/Terminal.app"
            )
            menuEntries = [
                .custom(terminalConfig),
                .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
            ]
            configService.saveEntries(menuEntries)
            syncScriptsInBackground()
        } else {
            menuEntries = existing
            syncScriptsInBackground()
        }
    }

    private func migrateCompositeCommandTemplatesIfNeeded(_ entries: [MenuEntry]) -> [MenuEntry] {
        var didChange = false
        let migratedEntries = entries.map { entry -> MenuEntry in
            guard case .composite(var config) = entry else {
                return entry
            }

            for index in config.steps.indices {
                let step = config.steps[index]
                guard step.bundleId == "com.microsoft.VSCode",
                      CompositeCommandTemplates.shouldMigrateVSCodeTemplate(step.commandTemplate) else {
                    continue
                }

                config.steps[index].commandTemplate = CompositeCommandTemplates.vsCodeCLI
                didChange = true
            }

            return .composite(config)
        }

        if didChange {
            configService.saveEntries(migratedEntries)
        }
        return migratedEntries
    }

    /// 从 AppInfo 创建 MenuItemConfig 并添加到菜单
    func addMenuItem(from appInfo: AppInfo) {
        guard !containsCustomMenuItem(matching: appInfo) else { return }
        let newItem = MenuItemConfig(
            appName: appInfo.name,
            bundleId: appInfo.bundleId,
            appPath: appInfo.path
        )
        menuEntries.append(.custom(newItem))
        saveAndSync()
    }

    func addEmptyCompositeCommand() {
        let composite = CompositeMenuItemConfig(
            name: "新组合命令",
            iconName: "rectangle.stack.badge.play",
            steps: []
        )
        menuEntries.append(.composite(composite))
        saveAndSync()
    }

    func addEditorTerminalPreset() {
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
                    self.createEditorTerminalPresetFromDiscoveredApps()
                }
            }
        } else {
            createEditorTerminalPresetFromDiscoveredApps()
        }
    }

    private func createEditorTerminalPresetFromDiscoveredApps() {
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
        menuEntries.append(.composite(composite))
        compositePresetMessage = nil
        saveAndSync()
    }

    /// 批量添加多个应用到菜单（只触发一次 saveAndSync）
    func addMenuItems(from appInfos: [AppInfo]) {
        var existingBundleIds = Set<String>()
        var existingPaths = Set<String>()
        for entry in menuEntries {
            guard case .custom(let item) = entry else { continue }
            if let bundleId = item.bundleId {
                existingBundleIds.insert(bundleId)
            }
            existingPaths.insert(item.appPath)
        }
        var didAddItem = false

        for appInfo in appInfos {
            if let bundleId = appInfo.bundleId, existingBundleIds.contains(bundleId) {
                continue
            }
            guard !existingPaths.contains(appInfo.path) else { continue }

            let newItem = MenuItemConfig(
                appName: appInfo.name,
                bundleId: appInfo.bundleId,
                appPath: appInfo.path
            )
            menuEntries.append(.custom(newItem))
            if let bundleId = appInfo.bundleId {
                existingBundleIds.insert(bundleId)
            }
            existingPaths.insert(appInfo.path)
            didAddItem = true
        }
        if didAddItem {
            saveAndSync()
        }
    }

    private func containsCustomMenuItem(matching appInfo: AppInfo) -> Bool {
        for entry in menuEntries {
            guard case .custom(let item) = entry else { continue }
            if let bundleId = appInfo.bundleId, item.bundleId == bundleId {
                return true
            }
            if item.appPath == appInfo.path {
                return true
            }
        }
        return false
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
    func moveEntry(from source: IndexSet, to destination: Int) {
        menuEntries.move(fromOffsets: source, toOffset: destination)
        saveAndSync()
    }

    /// 删除指定位置的菜单项
    func removeEntry(at offsets: IndexSet) {
        let removableOffsets = offsets.filter { index in
            switch menuEntries[index] {
            case .custom, .composite:
                return true
            case .builtIn:
                return false
            }
        }
        menuEntries.remove(atOffsets: IndexSet(removableOffsets))
        saveAndSync()
    }

    /// 更新指定菜单项的自定义命令
    func updateCustomCommand(for itemId: UUID, command: String?) {
        guard let index = menuEntries.firstIndex(where: {
            if case .custom(let config) = $0 { return config.id == itemId }
            return false
        }) else { return }
        if case .custom(var config) = menuEntries[index] {
            config.customCommand = command
            menuEntries[index] = .custom(config)
        }
        saveAndSync()
    }

    func updateCompositeName(for compositeId: UUID, name: String) {
        updateComposite(for: compositeId) { config in
            config.name = name
        }
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
        updateComposite(for: compositeId) { config in
            guard let stepIndex = config.steps.firstIndex(where: { $0.id == stepId }) else {
                return
            }
            config.steps[stepIndex].name = name
            config.steps[stepIndex].commandTemplate = commandTemplate
            config.steps[stepIndex].appPath = appPath
            config.steps[stepIndex].bundleId = bundleId
            config.steps[stepIndex].isEnabled = isEnabled
        }
    }

    func addShellStep(to compositeId: UUID) {
        updateComposite(for: compositeId) { config in
            config.steps.append(
                CompositeCommandStep(
                    kind: .shell,
                    name: "Shell",
                    commandTemplate: "open -a Terminal {path}"
                )
            )
        }
    }

    func removeCompositeStep(compositeId: UUID, stepId: UUID) {
        updateComposite(for: compositeId) { config in
            config.steps.removeAll { $0.id == stepId }
        }
    }

    func moveCompositeStep(compositeId: UUID, from source: IndexSet, to destination: Int) {
        updateComposite(for: compositeId) { config in
            config.steps.move(fromOffsets: source, toOffset: destination)
        }
    }

    private func updateComposite(
        for compositeId: UUID,
        mutate: (inout CompositeMenuItemConfig) -> Void
    ) {
        guard let index = menuEntries.firstIndex(where: {
            if case .composite(let config) = $0 { return config.id == compositeId }
            return false
        }) else { return }
        guard case .composite(var config) = menuEntries[index] else { return }
        mutate(&config)
        menuEntries[index] = .composite(config)
        saveAndSync()
    }

    /// 切换菜单项的启用/禁用状态
    func toggleEntry(for entryId: String, isEnabled: Bool) {
        guard let index = menuEntries.firstIndex(where: { $0.id == entryId }) else { return }
        switch menuEntries[index] {
        case .builtIn(var item):
            item.isEnabled = isEnabled
            menuEntries[index] = .builtIn(item)
        case .custom(var config):
            config.isEnabled = isEnabled
            menuEntries[index] = .custom(config)
        case .composite(var config):
            config.isEnabled = isEnabled
            menuEntries[index] = .composite(config)
        }
        saveAndSync()
    }

    func updateMenuPresentationMode(_ mode: MenuPresentationMode) {
        guard menuPresentationMode != mode else { return }
        menuPresentationMode = mode
        configService.saveMenuPresentationMode(mode)
        DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
    }

    /// 保存配置 + 同步脚本 + 发送 Darwin Notification
    func saveAndSync() {
        configService.saveEntries(menuEntries)
        syncScriptsInBackground()
    }

    /// 串行队列确保脚本同步任务不会并发执行，避免竞态导致孤立脚本文件
    private static let syncQueue = DispatchQueue(label: "com.sunven.rcmm.scriptSync", qos: .userInitiated)

    private func syncScriptsInBackground() {
        let entries = menuEntries
        let publishStore = publishStore
        let errorQueue = errorQueue
        Self.syncQueue.async { [weak self] in
            let installer = ScriptInstallerService()
            installer.syncScripts(with: entries)
            DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
            Task { @MainActor in
                self?.scriptPublishStates = publishStore.loadAll()
                self?.errorRecords = errorQueue.loadAll()
            }
        }
    }
}
