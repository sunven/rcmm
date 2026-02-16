import Cocoa
import FinderSync
import RCMMShared
import os.log

class FinderSync: FIFinderSync {
    private let logger = Logger(
        subsystem: "com.sunven.rcmm.FinderExtension",
        category: "menu"
    )
    private let configService = SharedConfigService()
    private let scriptExecutor = ScriptExecutor()

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        logger.info("FinderSync Extension 已初始化")
    }

    // MARK: - Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let items = configService.load().sorted(by: { $0.sortOrder < $1.sortOrder })

        guard !items.isEmpty else {
            logger.warning("无菜单配置项")
            return menu
        }

        for item in items {
            let menuItem = NSMenuItem(
                title: "用 \(item.appName) 打开",
                action: #selector(openWithApp(_:)),
                keyEquivalent: ""
            )
            menuItem.representedObject = item.id.uuidString

            // 设置应用图标
            let icon = NSWorkspace.shared.icon(forFile: item.appPath)
            icon.size = NSSize(width: 16, height: 16)
            menuItem.image = icon

            menu.addItem(menuItem)
        }

        return menu
    }

    @objc func openWithApp(_ sender: NSMenuItem) {
        guard let itemId = sender.representedObject as? String else {
            logger.error("无效的菜单项: 缺少 representedObject")
            return
        }

        let items = configService.load()
        guard let item = items.first(where: { $0.id.uuidString == itemId }) else {
            logger.error("找不到菜单项配置: \(itemId)")
            return
        }

        // 解析目标目录路径
        guard let directoryPath = resolveDirectoryPath() else {
            logger.error("无法解析目标目录路径")
            return
        }

        logger.info("执行: \(item.appName) → \(directoryPath)")

        scriptExecutor.execute(
            scriptId: item.id.uuidString,
            directoryPath: directoryPath,
            menuItemName: item.appName
        )
    }

    /// 解析右键点击的目标目录路径
    private func resolveDirectoryPath() -> String? {
        let controller = FIFinderSyncController.default()

        // 优先使用 selectedItemURLs（右键点击具体项目时）
        if let selectedItems = controller.selectedItemURLs(), !selectedItems.isEmpty {
            let firstItem = selectedItems[0]
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: firstItem.path, isDirectory: &isDir),
               isDir.boolValue {
                return firstItem.path
            } else {
                // 文件：使用其父目录
                return firstItem.deletingLastPathComponent().path
            }
        }

        // 回退：使用 targetedURL（右键空白背景时）
        return controller.targetedURL()?.path
    }
}
