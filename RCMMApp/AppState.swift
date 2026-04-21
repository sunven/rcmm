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

@Observable
@MainActor
final class AppState {
    var menuEntries: [MenuEntry] = []
    var discoveredApps: [AppInfo] = []
    var popoverState: PopoverState = .normal
    var extensionStatus: ExtensionStatus = .unknown
    var errorRecords: [ErrorRecord] = []
    var autoRepairMessage: String? = nil
    var currentDisplayVersion = "未知版本"
    var updateState: AppUpdateState = .idle

    var isOnboardingCompleted: Bool {
        didSet {
            let defaults = UserDefaults(suiteName: AppGroupConstants.appGroupID)
            defaults?.set(isOnboardingCompleted, forKey: SharedKeys.onboardingCompleted)
        }
    }

    private var onboardingWindow: NSWindow?
    private var windowCloseObserver: Any?

    private var healthCheckTimer: Timer?
    private let healthCheckInterval: TimeInterval = 1800 // 30 分钟

    @ObservationIgnored private var sparkleUpdater: SparkleUpdaterService?
    @ObservationIgnored private let updateFeedClient = UpdateFeedClient()
    private let configService = SharedConfigService()
    private let errorQueue = SharedErrorQueue()
    private var hasTriggeredAutoRepair = false
    private let logger = Logger(
        subsystem: "com.sunven.rcmm",
        category: "appState"
    )

    init(forPreview: Bool = false) {
        let defaults = UserDefaults(suiteName: AppGroupConstants.appGroupID)
        isOnboardingCompleted = defaults?.bool(forKey: SharedKeys.onboardingCompleted) ?? false

        guard !forPreview else { return }

        if let bundleInfo = try? AppBundleUpdateInfo.current() {
            currentDisplayVersion = bundleInfo.displayVersion
        }
        sparkleUpdater = SparkleUpdaterService()

        loadMenuEntries()
        checkExtensionStatus()
        startHealthMonitoring()

        if !isOnboardingCompleted {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                self.showOnboardingIfNeeded()
            }
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
            // 立即清除脚本相关错误（UI + UserDefaults 同步清除）
            let remainingErrors = errorRecords.filter { record in
                !record.message.contains("脚本文件不存在") && !record.message.contains("脚本文件无法加载")
            }
            errorRecords = remainingErrors
            errorQueue.replaceAll(with: remainingErrors)
            autoRepairMessage = "正在自动修复脚本文件…"

            let items = menuEntries.compactMap { entry -> MenuItemConfig? in
                if case .custom(let config) = entry { return config }
                return nil
            }
            Self.syncQueue.async { [weak self] in
                let installer = ScriptInstallerService()
                installer.syncScripts(with: items)
                DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
                Task { @MainActor in
                    self?.autoRepairMessage = "已自动修复脚本文件"
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
        let newStatus = PluginKitService.checkHealth()
        let oldStatus = extensionStatus

        guard oldStatus != newStatus else { return }

        extensionStatus = newStatus

        switch newStatus {
        case .enabled:
            popoverState = .normal
        case .disabled:
            popoverState = .healthWarning
        case .unknown:
            popoverState = .normal
        }

        logger.info("Extension 状态变化: \(oldStatus.rawValue) → \(newStatus.rawValue), popoverState: \(String(describing: self.popoverState))")
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
            updateState = .installing(item)
            sparkleUpdater?.beginInteractiveUpdate()
        case .manualInstall(_, let fallbackURL):
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

    // MARK: - Onboarding Window

    func showOnboardingIfNeeded() {
        guard !isOnboardingCompleted, onboardingWindow == nil else { return }

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
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onboardingWindow = nil
                self?.windowCloseObserver = nil
                ActivationPolicyManager.hideToMenuBar()
            }
        }

        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)

        ActivationPolicyManager.activateAsRegularApp()
    }

    func closeOnboarding() {
        if let observer = windowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            windowCloseObserver = nil
        }
        onboardingWindow?.close()
        onboardingWindow = nil
        ActivationPolicyManager.hideToMenuBar()
    }

    // MARK: - Menu Items

    /// 从 SharedConfigService 加载已配置菜单项；首次启动时创建默认 Terminal 配置
    ///
    /// 注意: 每次启动都调用 syncScriptsInBackground() 是有意为之，确保脚本文件
    /// 与配置保持一致（防止脚本被手动删除或损坏的情况）。
    /// 优化建议: 未来可改为仅校验脚本文件是否存在，而非每次都重新编译。
    func loadMenuEntries() {
        let existing = configService.loadEntries()

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

    /// 从 AppInfo 创建 MenuItemConfig 并添加到菜单
    func addMenuItem(from appInfo: AppInfo) {
        let newItem = MenuItemConfig(
            appName: appInfo.name,
            bundleId: appInfo.bundleId,
            appPath: appInfo.path
        )
        menuEntries.append(.custom(newItem))
        saveAndSync()
    }

    /// 批量添加多个应用到菜单（只触发一次 saveAndSync）
    func addMenuItems(from appInfos: [AppInfo]) {
        for appInfo in appInfos {
            let newItem = MenuItemConfig(
                appName: appInfo.name,
                bundleId: appInfo.bundleId,
                appPath: appInfo.path
            )
            menuEntries.append(.custom(newItem))
        }
        if !appInfos.isEmpty {
            saveAndSync()
        }
    }

    /// 检查菜单中是否已包含指定应用（按 bundleId 或 appPath 匹配）
    func containsApp(bundleId: String?, appPath: String) -> Bool {
        for entry in menuEntries {
            if case .custom(let item) = entry {
                if let bundleId = bundleId, item.bundleId == bundleId {
                    return true
                }
                if item.appPath == appPath {
                    return true
                }
            }
        }
        return false
    }

    /// 移动菜单项到新位置（拖拽排序）
    func moveEntry(from source: IndexSet, to destination: Int) {
        menuEntries.move(fromOffsets: source, toOffset: destination)
        saveAndSync()
    }

    /// 删除指定位置的菜单项
    func removeEntry(at offsets: IndexSet) {
        let onlyCustomOffsets = offsets.filter { index in
            if case .custom = menuEntries[index] { return true }
            return false
        }
        menuEntries.remove(atOffsets: IndexSet(onlyCustomOffsets))
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
        }
        saveAndSync()
    }

    /// 保存配置 + 同步脚本 + 发送 Darwin Notification
    func saveAndSync() {
        configService.saveEntries(menuEntries)
        syncScriptsInBackground()
    }

    /// 串行队列确保脚本同步任务不会并发执行，避免竞态导致孤立脚本文件
    private static let syncQueue = DispatchQueue(label: "com.sunven.rcmm.scriptSync", qos: .userInitiated)

    private func syncScriptsInBackground() {
        let items = menuEntries.compactMap { entry -> MenuItemConfig? in
            if case .custom(let config) = entry { return config }
            return nil
        }
        Self.syncQueue.async {
            let installer = ScriptInstallerService()
            installer.syncScripts(with: items)
            DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
        }
    }
}
