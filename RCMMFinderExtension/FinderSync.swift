import Cocoa
import FinderSync
import RCMMShared
import os.log

class FinderSync: FIFinderSync {
    private let logger = Logger(
        subsystem: RuntimeConfiguration.finderExtensionBundleID,
        category: "menu"
    )
    private let configService = SharedConfigService()
    private let publishStore = ScriptPublishStore()
    private let scriptExecutor = ScriptExecutor()
    private var configObservation: DarwinObservation?
    private var currentMenuKind: FIMenuKind?

    override init() {
        super.init()
        let monitoredURLs = Self.monitoredDirectoryURLs()
        FIFinderSyncController.default().directoryURLs = monitoredURLs

        configObservation = DarwinNotificationCenter.shared.addObserver(
            name: NotificationNames.configChanged
        ) { [weak self] in
            self?.logger.info("收到配置变更通知，下次右键将使用最新配置")
        }

        logger.info(
            """
            FinderSync Extension 已初始化，已注册配置变更监听。
            监控目录：
            \(monitoredURLs.map(\.path).sorted().joined(separator: "\n"))
            """
        )
    }

    // MARK: - Toolbar

    override var toolbarItemName: String {
        "rcmm"
    }

    override var toolbarItemToolTip: String {
        "显示 rcmm 右键菜单"
    }

    override var toolbarItemImage: NSImage {
        if let image = NSImage(
            systemSymbolName: "contextualmenu.and.cursorarrow",
            accessibilityDescription: "rcmm"
        ) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            return image
        }

        return NSImage(size: NSSize(width: 18, height: 18))
    }

    // MARK: - Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        currentMenuKind = menuKind
        let menu = NSMenu(title: "")
        let entries = FinderMenuPresenter.visibleEntries(
            entries: configService.loadEntries(),
            publishStates: publishStore.loadAll()
        )
        let presentationMode = configService.loadMenuPresentationMode()

        logger.debug(
            "开始构建 Finder 菜单，menuKind=\(String(describing: menuKind), privacy: .public)，启用项数量=\(entries.count)，展示方式=\(presentationMode.rawValue, privacy: .public)"
        )

        guard !entries.isEmpty else {
            logger.warning("无菜单配置项")
            return menu
        }

        switch presentationMode {
        case .flat:
            addMenuItems(for: entries, to: menu)
        case .nestedUnderRCMM:
            let parentItem = NSMenuItem(title: "RCMM", action: nil, keyEquivalent: "")
            parentItem.image = makeMenuSymbolImage(
                named: "contextualmenu.and.cursorarrow",
                accessibilityDescription: "RCMM"
            )

            let submenu = NSMenu(title: "RCMM")
            addMenuItems(for: entries, to: submenu)
            parentItem.submenu = submenu
            menu.addItem(parentItem)
        }

        return menu
    }

    private func addMenuItems(for entries: [MenuEntry], to menu: NSMenu) {
        var customIndex = 0
        let publishStates = publishStore.loadAll()
        for entry in entries {
            switch entry {
            case .builtIn(let item):
                menu.addItem(makeBuiltInMenuItem(from: item))
            case .custom(let config):
                menu.addItem(makeCustomMenuItem(config, customIndex: customIndex))
                customIndex += 1
            case .composite(let config):
                menu.addItem(makeCompositeMenuItem(config))
            case .newFile(let config):
                if let item = makeNewFileMenuItem(config, publishStates: publishStates) {
                    menu.addItem(item)
                }
            }
        }
    }

    private func makeBuiltInMenuItem(from item: BuiltInMenuItem) -> NSMenuItem {
        let entry = MenuEntry.builtIn(item)
        let menuItem = NSMenuItem(
            title: entry.displayName,
            action: action(for: item.type),
            keyEquivalent: ""
        )
        menuItem.target = self

        if let symbolName = entry.systemSymbolName,
           let image = makeMenuSymbolImage(
               named: symbolName,
               accessibilityDescription: entry.displayName
           ) {
            menuItem.image = image
        }

        return menuItem
    }

    private func action(for builtInType: BuiltInType) -> Selector {
        switch builtInType {
        case .copyPath:
            return #selector(copyPath(_:))
        }
    }

    private func makeCustomMenuItem(
        _ config: MenuItemConfig,
        customIndex: Int
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(
            title: "用 \(config.appName) 打开",
            action: #selector(openScriptBackedEntry(_:)),
            keyEquivalent: ""
        )
        menuItem.representedObject = config.id.uuidString
        menuItem.identifier = NSUserInterfaceItemIdentifier(config.id.uuidString)
        menuItem.tag = customIndex
        menuItem.target = self

        if config.executionMode == .currentDirectory {
            menuItem.image = makeMenuSymbolImage(
                named: "terminal",
                accessibilityDescription: config.appName
            )
        } else {
            let icon = NSWorkspace.shared.icon(forFile: config.appPath)
            icon.size = NSSize(width: 16, height: 16)
            menuItem.image = icon
        }

        return menuItem
    }

    private func makeCompositeMenuItem(_ config: CompositeMenuItemConfig) -> NSMenuItem {
        let menuItem = NSMenuItem(
            title: config.name,
            action: #selector(openScriptBackedEntry(_:)),
            keyEquivalent: ""
        )
        menuItem.representedObject = config.id.uuidString
        menuItem.identifier = NSUserInterfaceItemIdentifier(config.id.uuidString)
        menuItem.tag = -1
        menuItem.target = self

        if let symbolName = config.iconName,
           let image = makeMenuSymbolImage(
               named: symbolName,
               accessibilityDescription: config.name
           ) {
            menuItem.image = image
        }

        return menuItem
    }

    private func makeNewFileMenuItem(
        _ config: NewFileMenuConfig,
        publishStates: [String: ScriptPublishState]
    ) -> NSMenuItem? {
        let templates = FinderMenuPresenter.visibleNewFileTemplates(
            for: config,
            publishStates: publishStates
        )
        guard !templates.isEmpty else { return nil }

        let parentItem = NSMenuItem(title: config.name, action: nil, keyEquivalent: "")
        if let symbolName = config.iconName,
           let image = makeMenuSymbolImage(
               named: symbolName,
               accessibilityDescription: config.name
           ) {
            parentItem.image = image
        }

        let submenu = NSMenu(title: config.name)
        for template in templates {
            let scriptID = MenuEntryScriptPolicy.newFileScriptID(
                menuID: config.id,
                templateID: template.id
            )
            let childItem = NSMenuItem(
                title: template.displayName,
                action: #selector(openScriptBackedEntry(_:)),
                keyEquivalent: ""
            )
            childItem.representedObject = scriptID
            childItem.identifier = NSUserInterfaceItemIdentifier(scriptID)
            childItem.tag = -1
            childItem.target = self
            childItem.image = makeMenuSymbolImage(
                named: symbolName(for: template),
                accessibilityDescription: template.displayName
            )
            submenu.addItem(childItem)
        }
        parentItem.submenu = submenu
        return parentItem
    }

    private func symbolName(for template: NewFileTemplateConfig) -> String {
        switch template.creationMode {
        case .emptyFile:
            return "doc"
        case .textContent:
            return "doc.text"
        case .copyTemplate:
            return "doc.on.doc"
        }
    }

    private func makeMenuSymbolImage(
        named symbolName: String,
        accessibilityDescription: String
    ) -> NSImage? {
        guard let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityDescription
        ) else {
            logger.error("无法创建系统图标: \(symbolName)")
            return nil
        }

        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = true
        return image
    }

    @objc func openScriptBackedEntry(_ sender: NSMenuItem) {
        guard let entry = resolveScriptBackedEntry(sender) else {
            logger.error(
                """
                找不到菜单项配置：title=\(sender.title, privacy: .public)，\
                tag=\(sender.tag, privacy: .public)，\
                representedObject=\(String(describing: sender.representedObject), privacy: .private)
                """
            )
            return
        }

        guard let targetPath = resolveTargetPath(for: entry) else {
            logger.error("无法解析目标路径")
            return
        }
        let executionPath = FinderTargetPathResolver.executionPath(
            for: targetPath,
            targetPolicy: entry.targetPolicy
        )

        logger.info("执行: \(entry.displayName, privacy: .public) → \(executionPath, privacy: .private)")

        scriptExecutor.execute(
            scriptId: entry.id,
            targetPath: executionPath,
            menuItemName: entry.displayName
        )
    }

    @objc func openWithApp(_ sender: NSMenuItem) {
        openScriptBackedEntry(sender)
    }

    private func resolveScriptBackedEntry(_ sender: NSMenuItem) -> ScriptBackedMenuEntry? {
        let visibleEntries = FinderMenuPresenter.visibleEntries(
            entries: configService.loadEntries(),
            publishStates: publishStore.loadAll()
        )
        let scriptBackedEntries = visibleEntries.flatMap(MenuEntryScriptPolicy.scriptBackedEntries)

        let customItems = visibleEntries.compactMap { entry -> MenuItemConfig? in
            if case .custom(let config) = entry { return config }
            return nil
        }

        logger.debug(
            """
            解析脚本菜单：title=\(sender.title, privacy: .public)，\
            tag=\(sender.tag, privacy: .public)，\
            representedID=\((sender.representedObject as? String) ?? "nil", privacy: .public)，\
            identifier=\(sender.identifier?.rawValue ?? "nil", privacy: .public)
            """
        )

        return MenuItemResolver.scriptBackedEntry(
            in: scriptBackedEntries,
            customItems: customItems,
            representedObject: sender.representedObject,
            identifier: sender.identifier?.rawValue,
            tag: sender.tag,
            title: sender.title,
            parentMenuTitle: parentMenuTitle(for: sender)
        )
    }

    private func parentMenuTitle(for sender: NSMenuItem) -> String? {
        if let menuTitle = sender.menu?.title, !menuTitle.isEmpty {
            return menuTitle
        }
        if let parentTitle = sender.parent?.title, !parentTitle.isEmpty {
            return parentTitle
        }
        return nil
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

    private static func monitoredDirectoryURLs(
        fileManager: FileManager = .default
    ) -> Set<URL> {
        let candidatePaths = [
            NSHomeDirectory(),
            "/Users",
            "/Applications",
            "/System/Applications",
            "/System/Volumes/Data",
            "/System/Volumes/Data/Users",
            "/System/Volumes/Data/Applications",
        ]

        let candidateURLs = candidatePaths.compactMap { path -> URL? in
            var isDirectory = ObjCBool(false)
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                return nil
            }
            return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        }

        let visibleVolumeURLs = (try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes", isDirectory: true),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return Set(candidateURLs + visibleVolumeURLs.map(\.standardizedFileURL))
    }

    /// 解析右键点击的目标路径（文件或目录）
    private func resolveTargetPath(for entry: ScriptBackedMenuEntry) -> String? {
        let controller = FIFinderSyncController.default()

        if entry.kind == .newFileTemplate,
           currentMenuKind == .contextualMenuForContainer,
           let targetedURL = controller.targetedURL() {
            return targetedURL.path
        }

        return resolveTargetPath()
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
