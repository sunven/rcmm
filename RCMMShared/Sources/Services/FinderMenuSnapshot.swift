import Foundation

/// `NSMenuItem` 上可能跨进程回传的字段，纯值中间层。
///
/// 扩展侧只负责 `MenuItemFields` ↔ `NSMenuItem` 的机械转换，往返正确性在 RCMMShared 内可测。
public struct MenuItemFields: Equatable, Sendable {
    public let title: String
    public let tag: Int

    public init(title: String, tag: Int) {
        self.title = title
        self.tag = tag
    }

    /// Finder 实际回传的字段组合。
    ///
    /// 实测结论（见 ADR-0004）：Finder 不会把扩展构造的 `NSMenuItem` 原样传回，而是用自己
    /// 重建的裸菜单项回调，**只保留 `title`、`tag`、`action`**；`representedObject` 与
    /// 父菜单标题恒为 nil，`identifier` 被覆写为 action selector 名。因此本类型只保留
    /// 这两个字段 —— 其余字段既然永远拿不到，就不该出现在接口里。
    public static func finderObserved(title: String, tag: Int) -> MenuItemFields {
        MenuItemFields(title: title, tag: tag)
    }
}

/// 一次菜单点击的反解结果。
public enum FinderMenuResolution: Equatable, Sendable {
    case resolved(ScriptBackedMenuEntry)
    /// tag 不属于当前快照 —— 菜单打开后配置发生了变更。
    case staleSnapshot
    /// 索引命中但标题不符 —— 快照内部不一致，不应发生。
    case titleMismatch(expected: String, actual: String)
    /// 该菜单项不是 Script-Backed（内置项或父项）。
    case notScriptBacked

    public var entry: ScriptBackedMenuEntry? {
        guard case .resolved(let entry) = self else { return nil }
        return entry
    }
}

/// Finder 右键菜单的不可变快照。
///
/// **不变量**：构造菜单与反解点击必须使用同一份快照。描述树与身份索引在同一次初始化里
/// 产出，`generation` 编进 tag，消除「按旧菜单点击、按新配置解析」的时间窗。
public struct FinderMenuSnapshot: Sendable {
    public let entries: [MenuEntry]
    public let publishStates: [String: ScriptPublishState]
    public let presentationMode: MenuPresentationMode
    public let applicationIcons: [String: Data]

    /// 通过 Publish State 过滤后真正会出现在菜单里的 Menu Entry。
    public let visibleEntries: [MenuEntry]
    /// 本快照的序号，编进每个 Script-Backed 菜单项的 tag。
    public let generation: Int

    private let layout: FinderMenuLayout
    private let entriesByScriptID: [String: ScriptBackedMenuEntry]

    /// 构造菜单用的描述树。
    public var descriptors: [FinderMenuItemDescriptor] { layout.descriptors }

    public static let empty = FinderMenuSnapshot(
        entries: [],
        publishStates: [:],
        presentationMode: .flat,
        applicationIcons: [:],
        generation: 0
    )

    /// - Parameter generation: 每次重新读盘递增，须 ≥ 1；0 仅用于空快照。
    public init(
        entries: [MenuEntry],
        publishStates: [String: ScriptPublishState],
        presentationMode: MenuPresentationMode,
        applicationIcons: [String: Data],
        generation: Int
    ) {
        self.entries = entries
        self.publishStates = publishStates
        self.presentationMode = presentationMode
        self.applicationIcons = applicationIcons
        self.generation = generation

        let visibleEntries = FinderMenuPresenter.visibleEntries(
            entries: entries,
            publishStates: publishStates
        )
        self.visibleEntries = visibleEntries
        self.layout = FinderMenuDescriptorBuilder.layout(
            visibleEntries: visibleEntries,
            publishStates: publishStates,
            presentationMode: presentationMode,
            applicationIcons: applicationIcons,
            generation: generation
        )
        self.entriesByScriptID = Dictionary(
            visibleEntries
                .flatMap(MenuEntryScriptPolicy.scriptBackedEntries)
                .map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// 从点击回传的字段反解 Script-Backed Entry。
    ///
    /// 主路径是 tag 索引；标题相等校验作纵深防御。两者都不依赖标题解析，
    /// 因此同名菜单项、跨父菜单的同名模板都能各自路由。
    public func resolve(_ fields: MenuItemFields) -> FinderMenuResolution {
        guard let decoded = FinderMenuItemTag.decode(fields.tag) else {
            return .notScriptBacked
        }

        guard decoded.generation == generation,
              decoded.index < layout.indexedItems.count else {
            return .staleSnapshot
        }

        let indexed = layout.indexedItems[decoded.index]
        guard indexed.title == fields.title else {
            return .titleMismatch(expected: indexed.title, actual: fields.title)
        }

        guard let entry = entriesByScriptID[indexed.scriptID] else {
            return .staleSnapshot
        }

        return .resolved(entry)
    }

    /// 描述树里全部 Script-Backed 项，按 Finder 实测保真度展平成「点击」。
    ///
    /// 往返不变量的输入：每一个 click 都应当能反解回构造它的那个 scriptID。
    public var observedScriptBackedClicks: [(scriptID: String, fields: MenuItemFields)] {
        descriptors.flatMap(Self.observedClicks)
    }

    private static func observedClicks(
        in descriptor: FinderMenuItemDescriptor
    ) -> [(scriptID: String, fields: MenuItemFields)] {
        var clicks: [(scriptID: String, fields: MenuItemFields)] = []

        if case .scriptBacked(let identity) = descriptor.action {
            clicks.append(
                (
                    identity.scriptID,
                    MenuItemFields.finderObserved(
                        title: descriptor.title,
                        tag: identity.tag
                    )
                )
            )
        }

        return clicks + descriptor.children.flatMap(observedClicks)
    }
}
