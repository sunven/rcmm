import Foundation
import os.log
import RCMMShared

@Observable
@MainActor
final class AppState {
    var menuItems: [MenuItemConfig] = []
    var discoveredApps: [AppInfo] = []

    private let configService = SharedConfigService()
    private let logger = Logger(
        subsystem: "com.sunven.rcmm",
        category: "appState"
    )

    init() {
        loadMenuItems()
    }

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
                appPath: "/Applications/Utilities/Terminal.app",
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

    /// 删除指定位置的菜单项
    func removeMenuItem(at offsets: IndexSet) {
        menuItems.remove(atOffsets: offsets)
        for (index, _) in menuItems.enumerated() {
            menuItems[index].sortOrder = index
        }
        saveAndSync()
    }

    /// 保存配置 + 同步脚本 + 发送 Darwin Notification
    func saveAndSync() {
        configService.save(menuItems)
        syncScriptsInBackground()
    }

    private func syncScriptsInBackground() {
        let items = menuItems
        DispatchQueue.global(qos: .userInitiated).async {
            let installer = ScriptInstallerService()
            installer.syncScripts(with: items)
            DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
        }
    }
}
