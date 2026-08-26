import Cocoa
import FinderSync
import RCMMShared
import os.log

class FinderSync: FIFinderSync {
    private struct CleanNodeModulesRequest {
        let directories: [String]
        let scriptID: String
        let menuItemName: String
    }

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
    private var cleanNodeModulesPanel: NSPanel?
    private var cleanNodeModulesRequest: CleanNodeModulesRequest?

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
            accessibilityDescription: nil
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
            "开始构建 Finder 菜单，menuKind=\(String(describing: menuKind), privacy: .public)，启用项数量=\(snapshot.visibleEntryCount)，展示方式=\(snapshot.presentationMode.rawValue, privacy: .public)"
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
            action: descriptor.action
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
            case .cleanNodeModules:
                return nil
            }
        case .scriptBacked:
            return #selector(openScriptBackedEntry(_:))
        case .container:
            return nil
        }
    }

    private func makeImage(
        from icon: FinderMenuIconSource,
        action: FinderMenuItemAction
    ) -> NSImage? {
        switch icon {
        case .symbol(let symbolName):
            let color: NSColor?
            if case .scriptBacked(let identity) = action,
               identity.scriptID == "builtIn.cleanNodeModules" {
                color = .systemRed
            } else {
                color = nil
            }
            return makeMenuSymbolImage(named: symbolName, color: color)
        case .applicationIcon(let data, let fallbackSymbolName):
            return makeApplicationIconImage(from: data) ?? makeMenuSymbolImage(named: fallbackSymbolName)
        case .none:
            return nil
        }
    }

    private func makeMenuSymbolImage(
        named symbolName: String,
        color: NSColor? = nil
    ) -> NSImage? {
        guard let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        ) else {
            logger.error("无法创建系统图标: \(symbolName)")
            return nil
        }

        let renderedImage: NSImage
        if let color,
           let configuredImage = image.withSymbolConfiguration(
               NSImage.SymbolConfiguration(paletteColors: [color])
           ) {
            renderedImage = configuredImage
            renderedImage.isTemplate = false
        } else {
            renderedImage = image
            renderedImage.isTemplate = true
        }
        renderedImage.size = NSSize(width: 16, height: 16)
        return renderedImage
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

        if case .builtIn(type: .cleanNodeModules) = entry.source {
            scriptExecutor.listNodeModules(
                scriptId: entry.id,
                targetPath: executionPath,
                menuItemName: entry.displayName
            ) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard case .success(let directories) = result else {
                        self.logger.error("无法获取待清理的 node_modules 目录")
                        return
                    }
                    let sortedDirectories = directories.sorted()
                    guard !sortedDirectories.isEmpty else {
                        self.showNoNodeModulesAlert()
                        return
                    }

                    self.showCleanNodeModulesConfirmation(
                        directories: sortedDirectories,
                        scriptID: entry.id,
                        menuItemName: entry.displayName
                    )
                }
            }
            return
        }

        logger.info("执行: \(entry.displayName, privacy: .public) → \(executionPath, privacy: .private)")

        scriptExecutor.execute(
            scriptId: entry.id,
            targetPath: executionPath,
            menuItemName: entry.displayName
        )
    }

    private func showNoNodeModulesAlert() {
        let alert = NSAlert()
        alert.messageText = "没有找到 node_modules"
        alert.informativeText = "当前目录及其子目录中没有可清理的 node_modules。"
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func showCleanNodeModulesConfirmation(
        directories: [String],
        scriptID: String,
        menuItemName: String
    ) {
        guard cleanNodeModulesPanel == nil else {
            cleanNodeModulesPanel?.makeKeyAndOrderFront(nil)
            return
        }

        let scrollView = NSTextView.scrollableTextView()
        scrollView.frame = NSRect(x: 20, y: 62, width: 520, height: 220)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .bezelBorder

        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }
        textView.string = directories.joined(separator: "\n")
        textView.isEditable = false
        textView.isSelectable = true
        textView.isHorizontallyResizable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 430),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.title = "清理 node_modules"
        panel.level = .modalPanel
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 430))
        panel.contentView = contentView

        let iconView = NSImageView(frame: NSRect(x: 248, y: 350, width: 64, height: 64))
        iconView.image = NSImage(named: NSImage.applicationIconName)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)

        let messageLabel = NSTextField(labelWithString: "将清理 \(directories.count) 个 node_modules 目录")
        messageLabel.frame = NSRect(x: 20, y: 320, width: 520, height: 22)
        messageLabel.alignment = .center
        messageLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        contentView.addSubview(messageLabel)

        let infoLabel = NSTextField(labelWithString: "以下目录将被永久删除，此操作不可撤销：")
        infoLabel.frame = NSRect(x: 20, y: 294, width: 520, height: 18)
        infoLabel.alignment = .center
        infoLabel.textColor = .secondaryLabelColor
        contentView.addSubview(infoLabel)
        contentView.addSubview(scrollView)

        let cancelButton = NSButton(
            title: "取消",
            target: self,
            action: #selector(dismissCleanNodeModulesPanel(_:))
        )
        cancelButton.frame = NSRect(x: 150, y: 18, width: 120, height: 30)
        contentView.addSubview(cancelButton)

        let cleanButton = NSButton(
            title: "清理",
            target: self,
            action: #selector(beginCleanNodeModules(_:))
        )
        cleanButton.frame = NSRect(x: 290, y: 18, width: 120, height: 30)
        cleanButton.bezelStyle = .rounded
        cleanButton.bezelColor = .systemRed
        cleanButton.contentTintColor = .white
        cleanButton.hasDestructiveAction = true
        contentView.addSubview(cleanButton)

        cleanNodeModulesRequest = CleanNodeModulesRequest(
            directories: directories,
            scriptID: scriptID,
            menuItemName: menuItemName
        )
        cleanNodeModulesPanel = panel
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func beginCleanNodeModules(_ sender: NSButton) {
        guard let panel = cleanNodeModulesPanel,
              let request = cleanNodeModulesRequest else {
            return
        }
        let directories = request.directories
        let scriptID = request.scriptID
        let menuItemName = request.menuItemName

        let previousTop = panel.frame.maxY
        panel.setContentSize(NSSize(width: 560, height: 250))
        var progressFrame = panel.frame
        progressFrame.origin.y = previousTop - progressFrame.height
        panel.setFrame(progressFrame, display: true, animate: true)

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 250))
        panel.contentView = contentView

        let iconView = NSImageView(frame: NSRect(x: 252, y: 178, width: 56, height: 56))
        iconView.image = NSImage(named: NSImage.applicationIconName)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        contentView.addSubview(iconView)

        let messageLabel = NSTextField(labelWithString: "正在清理 node_modules")
        messageLabel.frame = NSRect(x: 24, y: 148, width: 512, height: 22)
        messageLabel.alignment = .center
        messageLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        contentView.addSubview(messageLabel)

        let infoLabel = NSTextField(labelWithString: "请稍候，删除过程中请不要退出 rcmm。")
        infoLabel.frame = NSRect(x: 24, y: 124, width: 512, height: 18)
        infoLabel.alignment = .center
        infoLabel.textColor = .secondaryLabelColor
        contentView.addSubview(infoLabel)

        let progressIndicator = NSProgressIndicator(frame: NSRect(x: 24, y: 96, width: 512, height: 16))
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = Double(directories.count)
        progressIndicator.doubleValue = 0
        progressIndicator.controlSize = .regular
        contentView.addSubview(progressIndicator)

        let statusLabel = NSTextField(labelWithString: "准备清理 0 / \(directories.count)")
        statusLabel.frame = NSRect(x: 24, y: 66, width: 512, height: 18)
        statusLabel.lineBreakMode = .byTruncatingMiddle
        contentView.addSubview(statusLabel)

        let pathLabel = NSTextField(labelWithString: "")
        pathLabel.frame = NSRect(x: 24, y: 44, width: 512, height: 18)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        contentView.addSubview(pathLabel)

        let closeButton = NSButton(
            title: "关闭",
            target: self,
            action: #selector(dismissCleanNodeModulesPanel(_:))
        )
        closeButton.frame = NSRect(x: 208, y: 10, width: 144, height: 28)
        closeButton.isEnabled = false
        contentView.addSubview(closeButton)

        cleanNodeModulesRequest = nil

        cleanNextNodeModule(
            at: 0,
            directories: directories,
            scriptID: scriptID,
            menuItemName: menuItemName,
            panel: panel,
            messageLabel: messageLabel,
            infoLabel: infoLabel,
            closeButton: closeButton,
            progressIndicator: progressIndicator,
            statusLabel: statusLabel,
            pathLabel: pathLabel
        )
    }

    @objc private func dismissCleanNodeModulesPanel(_ sender: NSButton) {
        cleanNodeModulesPanel?.orderOut(nil)
        cleanNodeModulesPanel = nil
        cleanNodeModulesRequest = nil
    }

    private func cleanNextNodeModule(
        at index: Int,
        directories: [String],
        scriptID: String,
        menuItemName: String,
        panel: NSPanel,
        messageLabel: NSTextField,
        infoLabel: NSTextField,
        closeButton: NSButton,
        progressIndicator: NSProgressIndicator,
        statusLabel: NSTextField,
        pathLabel: NSTextField,
        failures: [String] = []
    ) {
        guard index < directories.count else {
            progressIndicator.doubleValue = Double(directories.count)
            statusLabel.stringValue = "已完成 \(directories.count) / \(directories.count)"
            if failures.isEmpty {
                messageLabel.stringValue = "清理完成"
                infoLabel.stringValue = "已删除全部 \(directories.count) 个 node_modules 目录。"
            } else {
                messageLabel.stringValue = "清理完成，但有 \(failures.count) 个目录失败"
                infoLabel.stringValue = "成功 \(directories.count - failures.count) 个，失败 \(failures.count) 个。失败详情已记录到 rcmm。"
            }
            pathLabel.stringValue = ""
            closeButton.isEnabled = true
            panel.layoutIfNeeded()
            return
        }

        let directory = directories[index]
        statusLabel.stringValue = "正在清理 \(index + 1) / \(directories.count)"
        pathLabel.stringValue = directory
        logger.info("清理第 \(index + 1) / \(directories.count) 个目录: \(directory, privacy: .private)")

        scriptExecutor.cleanNodeModule(
            scriptId: scriptID,
            targetPath: directory,
            menuItemName: menuItemName
        ) { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                var updatedFailures = failures
                if error != nil {
                    updatedFailures.append(directory)
                }
                progressIndicator.doubleValue = Double(index + 1)
                self.cleanNextNodeModule(
                    at: index + 1,
                    directories: directories,
                    scriptID: scriptID,
                    menuItemName: menuItemName,
                    panel: panel,
                    messageLabel: messageLabel,
                    infoLabel: infoLabel,
                    closeButton: closeButton,
                    progressIndicator: progressIndicator,
                    statusLabel: statusLabel,
                    pathLabel: pathLabel,
                    failures: updatedFailures
                )
            }
        }
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

        if (entry.kind == .newFileTemplate || entry.kind == .builtIn),
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
