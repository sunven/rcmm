import Foundation
import os.log
import RCMMShared
import SwiftUI

@Observable
@MainActor
final class AppState {
    var menuItems: [MenuItemConfig] = []
    var discoveredApps: [AppInfo] = []
    var popoverState: PopoverState = .normal
    var extensionStatus: ExtensionStatus = .unknown
    var errorRecords: [ErrorRecord] = []
    var autoRepairMessage: String? = nil
    var copyPathEnabled: Bool {
        didSet {
            configService.saveCopyPathEnabled(copyPathEnabled)
            DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
        }
    }

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
        copyPathEnabled = forPreview ? false : configService.loadCopyPathEnabled()

        guard !forPreview else { return }

        loadMenuItems()
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

            let items = menuItems
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
    func loadMenuItems() {
        let existingItems = configService.load()

        if existingItems.isEmpty {
            let terminalConfig = MenuItemConfig(
                appName: "Terminal",
                bundleId: "com.apple.Terminal",
                appPath: "/System/Applications/Utilities/Terminal.app",
                sortOrder: 0
            )
            menuItems = [terminalConfig]
            configService.save(menuItems)
            syncScriptsInBackground()
        } else {
            menuItems = existingItems
            syncScriptsInBackground()
        }
    }

    /// 从 AppInfo 创建 MenuItemConfig 并添加到菜单
    func addMenuItem(from appInfo: AppInfo) {
        let newItem = MenuItemConfig(
            appName: appInfo.name,
            bundleId: appInfo.bundleId,
            appPath: appInfo.path,
            sortOrder: menuItems.count
        )
        menuItems.append(newItem)
        saveAndSync()
    }

    /// 批量添加多个应用到菜单（只触发一次 saveAndSync）
    func addMenuItems(from appInfos: [AppInfo]) {
        for appInfo in appInfos {
            let newItem = MenuItemConfig(
                appName: appInfo.name,
                bundleId: appInfo.bundleId,
                appPath: appInfo.path,
                sortOrder: menuItems.count
            )
            menuItems.append(newItem)
        }
        if !appInfos.isEmpty {
            saveAndSync()
        }
    }

    /// 检查菜单中是否已包含指定应用（按 bundleId 或 appPath 匹配）
    func containsApp(bundleId: String?, appPath: String) -> Bool {
        for item in menuItems {
            if let bundleId = bundleId, item.bundleId == bundleId {
                return true
            }
            if item.appPath == appPath {
                return true
            }
        }
        return false
    }

    /// 移动菜单项到新位置（拖拽排序）
    func moveMenuItem(from source: IndexSet, to destination: Int) {
        menuItems.move(fromOffsets: source, toOffset: destination)
        recalculateSortOrders()
        saveAndSync()
    }

    /// 删除指定位置的菜单项
    func removeMenuItem(at offsets: IndexSet) {
        menuItems.remove(atOffsets: offsets)
        recalculateSortOrders()
        saveAndSync()
    }

    /// 更新指定菜单项的自定义命令
    func updateCustomCommand(for itemId: UUID, command: String?) {
        guard let index = menuItems.firstIndex(where: { $0.id == itemId }) else { return }
        menuItems[index].customCommand = command
        saveAndSync()
    }

    /// 切换菜单项的启用/禁用状态
    func toggleMenuItem(for itemId: UUID, isEnabled: Bool) {
        guard let index = menuItems.firstIndex(where: { $0.id == itemId }) else { return }
        menuItems[index].isEnabled = isEnabled
        saveAndSync()
    }

    /// 重新计算所有菜单项的 sortOrder（索引即排序值）
    private func recalculateSortOrders() {
        for (index, _) in menuItems.enumerated() {
            menuItems[index].sortOrder = index
        }
    }

    /// 保存配置 + 同步脚本 + 发送 Darwin Notification
    func saveAndSync() {
        configService.save(menuItems)
        syncScriptsInBackground()
    }

    /// 串行队列确保脚本同步任务不会并发执行，避免竞态导致孤立脚本文件
    private static let syncQueue = DispatchQueue(label: "com.sunven.rcmm.scriptSync", qos: .userInitiated)

    private func syncScriptsInBackground() {
        let items = menuItems
        Self.syncQueue.async {
            let installer = ScriptInstallerService()
            installer.syncScripts(with: items)
            DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
        }
    }
}
