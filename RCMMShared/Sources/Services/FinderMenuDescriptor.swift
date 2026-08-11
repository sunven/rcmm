import Foundation

/// 菜单项图标来源。
///
/// RCMMShared 不依赖 AppKit（见 CLAUDE.md 的包依赖规则），因此只描述来源，
/// 由扩展侧的 adapter 转成 `NSImage`。
public enum FinderMenuIconSource: Equatable, Sendable {
    case symbol(String)
    /// 缓存的应用图标。`fallbackSymbolName` 供解码失败时退化使用。
    case applicationIcon(data: Data, fallbackSymbolName: String)
    case none
}

/// 写入 `NSMenuItem` 的身份字段。
///
/// 构造侧与反解侧共用同一个定义，避免菜单项身份的编码与解码分居两个 target。
/// 哪些字段能真正跨进程回传见 ADR-0004。
public struct FinderMenuItemIdentity: Equatable, Sendable {
    /// Script-Backed Entry 的 id，写入 `representedObject` 与 `identifier`。
    public let scriptID: String
    /// 菜单项序号。当前仅 custom 项有意义，其余为 `unindexedTag`。
    public let tag: Int

    public static let unindexedTag = -1

    public init(scriptID: String, tag: Int) {
        self.scriptID = scriptID
        self.tag = tag
    }
}

/// 菜单项点击后要做什么。
public enum FinderMenuItemAction: Equatable, Sendable {
    /// 内置功能，由扩展侧映射到 selector。
    case builtIn(BuiltInType)
    /// Script-Backed Entry，携带身份字段。
    case scriptBacked(FinderMenuItemIdentity)
    /// 只承载子菜单，本身不可点击。
    case container
}

/// Finder 右键菜单里一个菜单项的完整描述。
///
/// 树形结构：`children` 对应 `nestedUnderRCMM` 的 RCMM 子菜单与 New File Template 子菜单。
public struct FinderMenuItemDescriptor: Equatable, Sendable {
    public let title: String
    public let icon: FinderMenuIconSource
    public let action: FinderMenuItemAction
    public let children: [FinderMenuItemDescriptor]

    public init(
        title: String,
        icon: FinderMenuIconSource,
        action: FinderMenuItemAction,
        children: [FinderMenuItemDescriptor] = []
    ) {
        self.title = title
        self.icon = icon
        self.action = action
        self.children = children
    }
}

/// 由 Menu Entry 构造 Finder 右键菜单的描述树。
///
/// 标题格式、图标选择与身份字段的写入规则都只在这里定义一次；反解见
/// `FinderMenuSnapshot.scriptBackedEntry(for:)`。
public enum FinderMenuDescriptorBuilder: Sendable {
    public static let rootTitle = "RCMM"
    public static let rootSymbolName = "contextualmenu.and.cursorarrow"

    public static func descriptors(
        visibleEntries: [MenuEntry],
        publishStates: [String: ScriptPublishState],
        presentationMode: MenuPresentationMode,
        applicationIcons: [String: Data]
    ) -> [FinderMenuItemDescriptor] {
        let items = menuItemDescriptors(
            visibleEntries: visibleEntries,
            publishStates: publishStates,
            applicationIcons: applicationIcons
        )

        guard !items.isEmpty else { return [] }

        switch presentationMode {
        case .flat:
            return items
        case .nestedUnderRCMM:
            return [
                FinderMenuItemDescriptor(
                    title: rootTitle,
                    icon: .symbol(rootSymbolName),
                    action: .container,
                    children: items
                )
            ]
        }
    }

    /// custom 项的菜单标题。
    ///
    /// 该格式只在此处定义。反解不再从标题解析应用名，而是拿构造出的标题正向比对。
    public static func customMenuTitle(for config: MenuItemConfig) -> String {
        switch config.executionMode {
        case .selectedPath:
            return "用 \(config.appName) 打开"
        case .currentDirectory:
            return "运行 \(config.appName)"
        }
    }

    public static func symbolName(for template: NewFileTemplateConfig) -> String {
        switch template.creationMode {
        case .emptyFile:
            return "doc"
        case .textContent:
            return "doc.text"
        case .copyTemplate:
            return "doc.on.doc"
        }
    }

    private static func menuItemDescriptors(
        visibleEntries: [MenuEntry],
        publishStates: [String: ScriptPublishState],
        applicationIcons: [String: Data]
    ) -> [FinderMenuItemDescriptor] {
        var descriptors: [FinderMenuItemDescriptor] = []
        var customIndex = 0

        for entry in visibleEntries {
            switch entry {
            case .builtIn(let item):
                descriptors.append(builtInDescriptor(for: item))
            case .custom(let config):
                descriptors.append(
                    customDescriptor(
                        for: config,
                        customIndex: customIndex,
                        applicationIcons: applicationIcons
                    )
                )
                customIndex += 1
            case .composite(let config):
                descriptors.append(compositeDescriptor(for: config))
            case .newFile(let config):
                if let descriptor = newFileDescriptor(
                    for: config,
                    publishStates: publishStates
                ) {
                    descriptors.append(descriptor)
                }
            }
        }

        return descriptors
    }

    private static func builtInDescriptor(for item: BuiltInMenuItem) -> FinderMenuItemDescriptor {
        let entry = MenuEntry.builtIn(item)
        return FinderMenuItemDescriptor(
            title: entry.displayName,
            icon: entry.systemSymbolName.map(FinderMenuIconSource.symbol) ?? .none,
            action: .builtIn(item.type)
        )
    }

    private static func customDescriptor(
        for config: MenuItemConfig,
        customIndex: Int,
        applicationIcons: [String: Data]
    ) -> FinderMenuItemDescriptor {
        let icon: FinderMenuIconSource
        let placeholderSymbolName = FinderMenuIconPolicy.placeholderSymbolName(for: config)
        if let iconData = FinderMenuIconPolicy.applicationIconData(
            for: config,
            cachedIcons: applicationIcons
        ) {
            icon = .applicationIcon(
                data: iconData,
                fallbackSymbolName: placeholderSymbolName
            )
        } else {
            icon = .symbol(placeholderSymbolName)
        }

        return FinderMenuItemDescriptor(
            title: customMenuTitle(for: config),
            icon: icon,
            action: .scriptBacked(
                FinderMenuItemIdentity(
                    scriptID: config.id.uuidString,
                    tag: customIndex
                )
            )
        )
    }

    private static func compositeDescriptor(
        for config: CompositeMenuItemConfig
    ) -> FinderMenuItemDescriptor {
        FinderMenuItemDescriptor(
            title: config.name,
            icon: config.iconName.map(FinderMenuIconSource.symbol) ?? .none,
            action: .scriptBacked(
                FinderMenuItemIdentity(
                    scriptID: config.id.uuidString,
                    tag: FinderMenuItemIdentity.unindexedTag
                )
            )
        )
    }

    private static func newFileDescriptor(
        for config: NewFileMenuConfig,
        publishStates: [String: ScriptPublishState]
    ) -> FinderMenuItemDescriptor? {
        let templates = FinderMenuPresenter.visibleNewFileTemplates(
            for: config,
            publishStates: publishStates
        )
        guard !templates.isEmpty else { return nil }

        let children = templates.map { template in
            FinderMenuItemDescriptor(
                title: template.displayName,
                icon: .symbol(symbolName(for: template)),
                action: .scriptBacked(
                    FinderMenuItemIdentity(
                        scriptID: MenuEntryScriptPolicy.newFileScriptID(
                            menuID: config.id,
                            templateID: template.id
                        ),
                        tag: FinderMenuItemIdentity.unindexedTag
                    )
                )
            )
        }

        return FinderMenuItemDescriptor(
            title: config.name,
            icon: config.iconName.map(FinderMenuIconSource.symbol) ?? .none,
            action: .container,
            children: children
        )
    }
}
