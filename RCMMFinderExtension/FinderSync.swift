import Cocoa
import FinderSync
import RCMMShared
import os.log

class FinderSync: FIFinderSync {
    private struct MenuSnapshot {
        let entries: [MenuEntry]
        let publishStates: [String: ScriptPublishState]
        let presentationMode: MenuPresentationMode
        let visibleEntries: [MenuEntry]

        static let empty = MenuSnapshot(
            entries: [],
            publishStates: [:],
            presentationMode: .flat
        )

        init(
            entries: [MenuEntry],
            publishStates: [String: ScriptPublishState],
            presentationMode: MenuPresentationMode
        ) {
            self.entries = entries
            self.publishStates = publishStates
            self.presentationMode = presentationMode
            self.visibleEntries = FinderMenuPresenter.visibleEntries(
                entries: self.entries,
                publishStates: self.publishStates
            )
        }

        var customAppPaths: Set<String> {
            Set(visibleEntries.compactMap { entry in
                guard case .custom(let config) = entry,
                      FinderMenuIconPolicy.shouldPreloadApplicationIcon(for: config) else {
                    return nil
                }
                return config.appPath.trimmingCharacters(in: .whitespacesAndNewlines)
            })
        }
    }

    private let logger = Logger(
        subsystem: RuntimeConfiguration.finderExtensionBundleID,
        category: "menu"
    )
    private let configService = SharedConfigService()
    private let publishStore = ScriptPublishStore()
    private let scriptExecutor = ScriptExecutor()
    private let preferencesURL = SharedPreferencesStore.appGroupPreferencesURL()
    private let menuSnapshotLock = NSLock()
    private let iconCacheLock = NSLock()
    private let iconLoadQueue = DispatchQueue(label: "com.sunven.rcmm.finder-icon-cache", qos: .utility)
    private var menuSnapshot = MenuSnapshot.empty
    private var menuCacheMetadata: FinderMenuCacheMetadata?
    private var iconCache: [String: NSImage] = [:]
    private var pendingIconLoads: Set<String> = []
    private var configObservation: DarwinObservation?
    private var currentMenuKind: FIMenuKind?

    override init() {
        super.init()
        let monitoredURLs = Self.monitoredDirectoryURLs()
        FIFinderSyncController.default().directoryURLs = monitoredURLs

        reloadMenuSnapshot()

        configObservation = DarwinNotificationCenter.shared.addObserver(
            name: NotificationNames.configChanged
        ) { [weak self] in
            self?.reloadMenuSnapshot()
            self?.logger.info("收到配置变更通知，已刷新 Finder 菜单缓存")
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
        refreshMenuSnapshotIfNeeded()
        let snapshot = currentMenuSnapshot()
        let entries = snapshot.visibleEntries

        logger.debug(
            "开始构建 Finder 菜单，menuKind=\(String(describing: menuKind), privacy: .public)，启用项数量=\(entries.count)，展示方式=\(snapshot.presentationMode.rawValue, privacy: .public)"
        )

        guard !entries.isEmpty else {
            logger.warning("无菜单配置项")
            return menu
        }

        switch snapshot.presentationMode {
        case .flat:
            addMenuItems(
                for: entries,
                publishStates: snapshot.publishStates,
                to: menu
            )
        case .nestedUnderRCMM:
            let parentItem = NSMenuItem(title: "RCMM", action: nil, keyEquivalent: "")
            parentItem.image = makeMenuSymbolImage(
                named: "contextualmenu.and.cursorarrow",
                accessibilityDescription: "RCMM"
            )

            let submenu = NSMenu(title: "RCMM")
            addMenuItems(
                for: entries,
                publishStates: snapshot.publishStates,
                to: submenu
            )
            parentItem.submenu = submenu
            menu.addItem(parentItem)
        }

        return menu
    }

    private func addMenuItems(
        for entries: [MenuEntry],
        publishStates: [String: ScriptPublishState],
        to menu: NSMenu
    ) {
        var customIndex = 0
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
            title: customMenuTitle(for: config),
            action: #selector(openScriptBackedEntry(_:)),
            keyEquivalent: ""
        )
        menuItem.representedObject = config.id.uuidString
        menuItem.identifier = NSUserInterfaceItemIdentifier(config.id.uuidString)
        menuItem.tag = customIndex
        menuItem.target = self

        if config.executionMode == .currentDirectory {
            menuItem.image = makeMenuSymbolImage(
                named: FinderMenuIconPolicy.placeholderSymbolName(for: config),
                accessibilityDescription: config.appName
            )
        } else if let icon = cachedAppIcon(forFile: config.appPath) {
            menuItem.image = icon
        } else {
            menuItem.image = makeMenuSymbolImage(
                named: FinderMenuIconPolicy.placeholderSymbolName(for: config),
                accessibilityDescription: config.appName
            )
            prewarmIconCache(forFile: config.appPath)
        }

        return menuItem
    }

    private func customMenuTitle(for config: MenuItemConfig) -> String {
        switch config.executionMode {
        case .selectedPath:
            return "用 \(config.appName) 打开"
        case .currentDirectory:
            return "运行 \(config.appName)"
        }
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
        let visibleEntries = currentMenuSnapshot().visibleEntries
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

    private func currentMenuSnapshot() -> MenuSnapshot {
        menuSnapshotLock.lock()
        defer { menuSnapshotLock.unlock() }
        return menuSnapshot
    }

    private func currentMenuCacheMetadata() -> FinderMenuCacheMetadata? {
        menuSnapshotLock.lock()
        defer { menuSnapshotLock.unlock() }
        return menuCacheMetadata
    }

    private func refreshMenuSnapshotIfNeeded() {
        let now = Date()
        let modificationDate = preferencesModificationDate()
        guard FinderMenuCacheInvalidationPolicy.shouldReload(
            metadata: currentMenuCacheMetadata(),
            currentPreferencesModificationDate: modificationDate,
            now: now
        ) else {
            return
        }

        reloadMenuSnapshot(
            preferencesModificationDate: modificationDate,
            loadedAt: now
        )
        logger.info("Finder 菜单缓存兜底刷新完成")
    }

    private func reloadMenuSnapshot() {
        reloadMenuSnapshot(
            preferencesModificationDate: preferencesModificationDate(),
            loadedAt: Date()
        )
    }

    private func reloadMenuSnapshot(
        preferencesModificationDate: Date?,
        loadedAt: Date
    ) {
        let snapshot = MenuSnapshot(
            entries: configService.loadEntries(),
            publishStates: publishStore.loadAll(),
            presentationMode: configService.loadMenuPresentationMode()
        )

        menuSnapshotLock.lock()
        menuSnapshot = snapshot
        menuCacheMetadata = FinderMenuCacheMetadata(
            preferencesModificationDate: preferencesModificationDate,
            loadedAt: loadedAt
        )
        menuSnapshotLock.unlock()

        pruneIconCache(keeping: snapshot.customAppPaths)
        prewarmIconCache(for: snapshot.customAppPaths)
    }

    private func preferencesModificationDate() -> Date? {
        SharedPreferencesStore.propertyListModificationDate(at: preferencesURL)
    }

    private func pruneIconCache(keeping paths: Set<String>) {
        iconCacheLock.lock()
        defer { iconCacheLock.unlock() }
        iconCache = iconCache.filter { paths.contains($0.key) }
        pendingIconLoads = pendingIconLoads.filter { paths.contains($0) }
    }

    private func cachedAppIcon(forFile path: String) -> NSImage? {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        iconCacheLock.lock()
        defer { iconCacheLock.unlock() }
        return iconCache[trimmedPath]
    }

    private func prewarmIconCache(for paths: Set<String>) {
        for path in paths {
            prewarmIconCache(forFile: path)
        }
    }

    private func prewarmIconCache(forFile path: String) {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return }

        iconCacheLock.lock()
        if iconCache[trimmedPath] != nil || pendingIconLoads.contains(trimmedPath) {
            iconCacheLock.unlock()
            return
        }
        pendingIconLoads.insert(trimmedPath)
        iconCacheLock.unlock()

        iconLoadQueue.async { [weak self] in
            guard let self else { return }
            let icon = NSWorkspace.shared.icon(forFile: trimmedPath)
            icon.size = NSSize(width: 16, height: 16)

            self.iconCacheLock.lock()
            self.iconCache[trimmedPath] = icon
            self.pendingIconLoads.remove(trimmedPath)
            self.iconCacheLock.unlock()
        }
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
