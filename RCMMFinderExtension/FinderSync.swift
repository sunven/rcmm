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
    private var configObservation: DarwinObservation?

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]

        configObservation = DarwinNotificationCenter.shared.addObserver(
            name: NotificationNames.configChanged
        ) { [weak self] in
            self?.logger.info("收到配置变更通知，下次右键将使用最新配置")
        }

        logger.info("FinderSync Extension 已初始化，已注册配置变更监听")
    }

    // MARK: - Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        let entries = configService.loadEntries()
            .filter { $0.isEnabled }

        guard !entries.isEmpty else {
            logger.warning("无菜单配置项")
            return menu
        }

        for entry in entries {
            switch entry {
            case .builtIn(let item):
                switch item.type {
                case .copyPath:
                    let copyPathItem = NSMenuItem(
                        title: "拷贝路径",
                        action: #selector(copyPath(_:)),
                        keyEquivalent: ""
                    )
                    copyPathItem.target = self
                    menu.addItem(copyPathItem)
                }
            case .custom(let config):
                let menuItem = NSMenuItem(
                    title: "用 \(config.appName) 打开",
                    action: #selector(openWithApp(_:)),
                    keyEquivalent: ""
                )
                menuItem.representedObject = config.id.uuidString
                menuItem.target = self

                let icon = NSWorkspace.shared.icon(forFile: config.appPath)
                icon.size = NSSize(width: 16, height: 16)
                menuItem.image = icon

                menu.addItem(menuItem)
            }
        }

        return menu
    }

    @objc func openWithApp(_ sender: NSMenuItem) {
        let title = sender.title
        let prefix = "用 "
        let suffix = " 打开"
        guard title.hasPrefix(prefix) && title.hasSuffix(suffix) else {
            logger.error("无效的菜单标题格式: \(title)")
            return
        }
        let appName = String(title.dropFirst(prefix.count).dropLast(suffix.count))

        let customItems = configService.loadEntries().compactMap { entry -> MenuItemConfig? in
            if case .custom(let config) = entry { return config }
            return nil
        }
        guard let item = customItems.first(where: { $0.appName == appName }) else {
            logger.error("找不到菜单项配置: \(appName)")
            return
        }

        guard let targetPath = resolveTargetPath() else {
            logger.error("无法解析目标路径")
            return
        }

        logger.info("执行: \(item.appName) → \(targetPath)")

        scriptExecutor.execute(
            scriptId: item.id.uuidString,
            targetPath: targetPath,
            menuItemName: item.appName
        )
    }

    @objc func copyPath(_ sender: NSMenuItem) {
        guard let targetPath = resolveTargetPath() else {
            logger.error("拷贝路径: 无法解析目标路径")
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(targetPath, forType: .string)

        logger.info("已拷贝路径: \(targetPath)")
    }

    /// 解析右键点击的目标路径（文件或目录）
    private func resolveTargetPath() -> String? {
        let controller = FIFinderSyncController.default()

        // 优先使用 selectedItemURLs（右键点击具体项目时）
        if let selectedItems = controller.selectedItemURLs(), !selectedItems.isEmpty {
            return selectedItems[0].path
        }

        // 回退：使用 targetedURL（右键空白背景时）
        return controller.targetedURL()?.path
    }
}
