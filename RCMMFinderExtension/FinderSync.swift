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
    private let iconStore = ApplicationIconStore()
    private let scriptExecutor = ScriptExecutor()
    private let errorQueue = SharedErrorQueue()
    private let preferencesURL = SharedPaths.extensionScriptsPreferencesURL()
    private let menuSnapshotLock = NSLock()
    private var menuSnapshot = FinderMenuSnapshot.empty
    private var menuCacheMetadata: FinderMenuCacheMetadata?
    /// 快照序号，编进菜单项 tag。从 1 起，每次重新读盘递增。
    private var snapshotGeneration = 0
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

        logger.debug(
            "开始构建 Finder 菜单，menuKind=\(String(describing: menuKind), privacy: .public)，启用项数量=\(snapshot.visibleEntries.count)，展示方式=\(snapshot.presentationMode.rawValue, privacy: .public)"
        )

        guard !snapshot.descriptors.isEmpty else {
            logger.warning("无菜单配置项")
            return menu
        }

        for descriptor in snapshot.descriptors {
            menu.addItem(makeMenuItem(from: descriptor))
        }

        return menu
    }

    // MARK: - Descriptor → NSMenuItem

    private func makeMenuItem(
        from descriptor: FinderMenuItemDescriptor
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(
            title: descriptor.title,
            action: selector(for: descriptor.action),
            keyEquivalent: ""
        )

        if case .scriptBacked(let identity) = descriptor.action {
            menuItem.representedObject = identity.scriptID
            menuItem.identifier = NSUserInterfaceItemIdentifier(identity.scriptID)
            menuItem.tag = identity.tag
        }

        if menuItem.action != nil {
            menuItem.target = self
        }

        menuItem.image = makeImage(
            from: descriptor.icon,
            accessibilityDescription: descriptor.title
        )

        if !descriptor.children.isEmpty {
            let submenu = NSMenu(title: descriptor.title)
            for child in descriptor.children {
                submenu.addItem(makeMenuItem(from: child))
            }
            menuItem.submenu = submenu
        }

        return menuItem
    }

    private func selector(for action: FinderMenuItemAction) -> Selector? {
        switch action {
        case .builtIn(let builtInType):
            switch builtInType {
            case .copyPath:
                return #selector(copyPath(_:))
            }
        case .scriptBacked:
            return #selector(openScriptBackedEntry(_:))
        case .container:
            return nil
        }
    }

    private func makeImage(
        from icon: FinderMenuIconSource,
        accessibilityDescription: String
    ) -> NSImage? {
        switch icon {
        case .symbol(let symbolName):
            return makeMenuSymbolImage(
                named: symbolName,
                accessibilityDescription: accessibilityDescription
            )
        case .applicationIcon(let data, let fallbackSymbolName):
            return makeApplicationIconImage(from: data) ?? makeMenuSymbolImage(
                named: fallbackSymbolName,
                accessibilityDescription: accessibilityDescription
            )
        case .none:
            return nil
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

    private func makeApplicationIconImage(from data: Data) -> NSImage? {
        guard let image = NSImage(data: data) else {
            logger.error("无法解码共享应用图标")
            return nil
        }

        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = false
        return image
    }

    @objc func openScriptBackedEntry(_ sender: NSMenuItem) {
        let fields = MenuItemFields(title: sender.title, tag: sender.tag)
        let resolution = currentMenuSnapshot().resolve(fields)

        guard let entry = resolution.entry else {
            reportRoutingFailure(resolution, fields: fields)
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

    /// 路由失败写入错误队列，让 App 侧看得见。
    ///
    /// 此前这里只打日志，用户的感受是「点了没反应」而 App 完全不知情。
    private func reportRoutingFailure(
        _ resolution: FinderMenuResolution,
        fields: MenuItemFields
    ) {
        let message: String
        switch resolution {
        case .resolved:
            return
        case .staleSnapshot:
            message = "菜单已过期，请重新打开右键菜单"
        case .titleMismatch(let expected, let actual):
            message = "菜单项标题不一致：期望 \(expected)，实际 \(actual)"
        case .notScriptBacked:
            message = "菜单项缺少可路由的标识"
        }

        logger.error(
            """
            菜单路由失败：\(message, privacy: .public)，\
            title=\(fields.title, privacy: .public)，tag=\(fields.tag, privacy: .public)
            """
        )

        errorQueue.upsert(
            ErrorRecord(
                source: "extension",
                message: message,
                context: fields.title,
                key: "menu.routing.\(fields.tag)",
                kind: .menuRouting
            )
        )
    }

    private func currentMenuSnapshot() -> FinderMenuSnapshot {
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
        menuSnapshotLock.lock()
        snapshotGeneration += 1
        let generation = snapshotGeneration
        menuSnapshotLock.unlock()

        let snapshot = FinderMenuSnapshot(
            entries: configService.loadEntries(),
            publishStates: publishStore.loadAll(),
            presentationMode: configService.loadMenuPresentationMode(),
            applicationIcons: iconStore.loadIcons(),
            generation: generation
        )

        menuSnapshotLock.lock()
        // 并发刷新时慢的那次可能后完成，不能让旧快照覆盖新快照 ——
        // 否则已发出菜单的 tag generation 会与当前快照不符，点击全部落空。
        if generation >= menuSnapshot.generation {
            menuSnapshot = snapshot
            menuCacheMetadata = FinderMenuCacheMetadata(
                preferencesModificationDate: preferencesModificationDate,
                loadedAt: loadedAt
            )
        }
        menuSnapshotLock.unlock()
    }

    private func preferencesModificationDate() -> Date? {
        SharedPreferencesStore.propertyListModificationDate(at: preferencesURL)
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
