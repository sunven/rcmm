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

/// `NSMenuItem.tag` 的编码。
///
/// `tag` 是实测唯一可靠的结构化载体（见 ADR-0004），因此身份走它而非标题。
/// 高位放快照 generation，低 16 位放菜单内序号：菜单打开后配置若发生变更，
/// 旧菜单的 tag 会因 generation 不符而直接失效，不会错位到另一个脚本。
enum FinderMenuItemTag: Sendable {
    static let indexBits = 16
    static let maximumIndex = (1 << indexBits) - 1

    /// 非 Script-Backed 菜单项（内置项、父项）的 tag。
    ///
    /// generation 从 1 起，因此任何有效编码都不会等于 0。
    static let none = 0

    /// 超出索引上限时返回 `none`，该项将无法路由并在点击时上报，而不是错位命中。
    static func encode(generation: Int, index: Int) -> Int {
        guard generation >= 1, index >= 0, index <= maximumIndex else {
            return none
        }
        return (generation << indexBits) | index
    }

    static func decode(_ tag: Int) -> (generation: Int, index: Int)? {
        guard tag > none else { return nil }
        return (tag >> indexBits, tag & maximumIndex)
    }
}

/// 写入 `NSMenuItem` 的身份字段。
///
/// 构造侧与反解侧共用同一个定义，避免菜单项身份的编码与解码分居两个 target。
public struct FinderMenuItemIdentity: Equatable, Sendable {
    /// Script-Backed Entry 的 id。
    public let scriptID: String
    /// 编码了快照 generation 与菜单内序号的 tag。
    public let tag: Int

    public init(scriptID: String, tag: Int) {
        self.scriptID = scriptID
        self.tag = tag
    }
}

/// 按 tag 序号排列的 Script-Backed 菜单项。
struct FinderMenuIndexedItem: Equatable, Sendable {
    let entry: ScriptBackedMenuEntry
    /// 构造时写入的标题，反解时用于相等校验。
    let title: String

    init(entry: ScriptBackedMenuEntry, title: String) {
        self.entry = entry
        self.title = title
    }
}

/// 一次菜单构造的产物：描述树与身份索引同源。
struct FinderMenuLayout: Sendable {
    let descriptors: [FinderMenuItemDescriptor]
    let indexedItems: [FinderMenuIndexedItem]

    static let empty = FinderMenuLayout(descriptors: [], indexedItems: [])

    init(
        descriptors: [FinderMenuItemDescriptor],
        indexedItems: [FinderMenuIndexedItem]
    ) {
        self.descriptors = descriptors
        self.indexedItems = indexedItems
    }
}

/// Snapshot 已完成评估和 Publish State 过滤后的一个顶层条目。
///
/// Descriptor Builder 只消费这个 implementation 类型，不再自行评估或过滤。
struct FinderMenuVisibleEntry: Sendable {
    let entry: MenuEntry
    let scriptBackedEntries: [ScriptBackedMenuEntry]
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

/// 按构造顺序分配 tag，并记录反解所需的索引。
private struct TagAllocator {
    let generation: Int
    private(set) var indexedItems: [FinderMenuIndexedItem] = []

    mutating func identity(
        for scriptBackedEntry: ScriptBackedMenuEntry,
        title: String
    ) -> FinderMenuItemIdentity {
        let index = indexedItems.count
        indexedItems.append(
            FinderMenuIndexedItem(entry: scriptBackedEntry, title: title)
        )
        return FinderMenuItemIdentity(
            scriptID: scriptBackedEntry.id,
            tag: FinderMenuItemTag.encode(generation: generation, index: index)
        )
    }
}

/// 由 Menu Entry 构造 Finder 右键菜单的描述树与身份索引。
///
/// 标题格式、图标选择与身份字段的写入规则都只在这里定义一次；反解见
/// `FinderMenuSnapshot.resolve(_:)`。
enum FinderMenuDescriptorBuilder: Sendable {
    static let rootTitle = "RCMM"
    static let rootSymbolName = "contextualmenu.and.cursorarrow"

    static func layout(
        visibleEntries: [FinderMenuVisibleEntry],
        presentationMode: MenuPresentationMode,
        applicationIcons: [String: Data],
        generation: Int
    ) -> FinderMenuLayout {
        var allocator = TagAllocator(generation: generation)
        let items = menuItemDescriptors(
            visibleEntries: visibleEntries,
            applicationIcons: applicationIcons,
            allocator: &allocator
        )

        guard !items.isEmpty else { return .empty }

        switch presentationMode {
        case .flat:
            return FinderMenuLayout(
                descriptors: items,
                indexedItems: allocator.indexedItems
            )
        case .nestedUnderRCMM:
            let root = FinderMenuItemDescriptor(
                title: rootTitle,
                icon: .symbol(rootSymbolName),
                action: .container,
                children: items
            )
            return FinderMenuLayout(
                descriptors: [root],
                indexedItems: allocator.indexedItems
            )
        }
    }

    /// custom 项的菜单标题。
    ///
    /// 该格式只在此处定义。反解不再从标题解析应用名，而是拿构造出的标题正向比对。
    static func customMenuTitle(for config: MenuItemConfig) -> String {
        switch config.executionMode {
        case .selectedPath:
            return "用 \(config.appName) 打开"
        case .currentDirectory:
            return "运行 \(config.appName)"
        }
    }

    static func symbolName(for template: NewFileTemplateConfig) -> String {
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
        visibleEntries: [FinderMenuVisibleEntry],
        applicationIcons: [String: Data],
        allocator: inout TagAllocator
    ) -> [FinderMenuItemDescriptor] {
        var descriptors: [FinderMenuItemDescriptor] = []

        for visibleEntry in visibleEntries {
            switch visibleEntry.entry {
            case .builtIn(let item):
                descriptors.append(builtInDescriptor(for: item))
            case .custom(let config):
                guard let scriptBackedEntry = visibleEntry.scriptBackedEntries.first else {
                    continue
                }
                descriptors.append(
                    customDescriptor(
                        for: config,
                        scriptBackedEntry: scriptBackedEntry,
                        applicationIcons: applicationIcons,
                        allocator: &allocator
                    )
                )
            case .composite(let config):
                guard let scriptBackedEntry = visibleEntry.scriptBackedEntries.first else {
                    continue
                }
                descriptors.append(
                    compositeDescriptor(
                        for: config,
                        scriptBackedEntry: scriptBackedEntry,
                        allocator: &allocator
                    )
                )
            case .newFile(let config):
                if let descriptor = newFileDescriptor(
                    for: config,
                    scriptBackedEntries: visibleEntry.scriptBackedEntries,
                    allocator: &allocator
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
        scriptBackedEntry: ScriptBackedMenuEntry,
        applicationIcons: [String: Data],
        allocator: inout TagAllocator
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

        let title = customMenuTitle(for: config)
        return FinderMenuItemDescriptor(
            title: title,
            icon: icon,
            action: .scriptBacked(
                allocator.identity(for: scriptBackedEntry, title: title)
            )
        )
    }

    private static func compositeDescriptor(
        for config: CompositeMenuItemConfig,
        scriptBackedEntry: ScriptBackedMenuEntry,
        allocator: inout TagAllocator
    ) -> FinderMenuItemDescriptor {
        FinderMenuItemDescriptor(
            title: config.name,
            icon: config.iconName.map(FinderMenuIconSource.symbol) ?? .none,
            action: .scriptBacked(
                allocator.identity(for: scriptBackedEntry, title: config.name)
            )
        )
    }

    private static func newFileDescriptor(
        for config: NewFileMenuConfig,
        scriptBackedEntries: [ScriptBackedMenuEntry],
        allocator: inout TagAllocator
    ) -> FinderMenuItemDescriptor? {
        guard !scriptBackedEntries.isEmpty else { return nil }

        var children: [FinderMenuItemDescriptor] = []
        for scriptBackedEntry in scriptBackedEntries {
            guard case .newFileTemplate(_, let templateID) = scriptBackedEntry.source,
                  let template = config.templates.first(where: { $0.id == templateID }) else {
                continue
            }
            children.append(
                FinderMenuItemDescriptor(
                    title: template.displayName,
                    icon: .symbol(symbolName(for: template)),
                    action: .scriptBacked(
                        allocator.identity(
                            for: scriptBackedEntry,
                            title: template.displayName
                        )
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
