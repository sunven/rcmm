import Foundation

/// `NSMenuItem` 上可能跨进程回传的字段，纯值中间层。
///
/// 扩展侧只负责 `MenuItemFields` ↔ `NSMenuItem` 的机械转换，往返正确性在 RCMMShared 内可测。
public struct MenuItemFields: Equatable, Sendable {
    public let title: String
    public let tag: Int
    public let identifier: String?
    public let representedObject: String?
    public let parentMenuTitle: String?

    public init(
        title: String,
        tag: Int,
        identifier: String? = nil,
        representedObject: String? = nil,
        parentMenuTitle: String? = nil
    ) {
        self.title = title
        self.tag = tag
        self.identifier = identifier
        self.representedObject = representedObject
        self.parentMenuTitle = parentMenuTitle
    }

    /// Finder 回调时 `identifier` 被覆写成的值。
    public static let observedActionSelectorName = "openScriptBackedEntry:"

    /// Finder 实际回传的字段组合。
    ///
    /// 实测结论（见 ADR-0004）：Finder 不会把扩展构造的 `NSMenuItem` 原样传回，而是用自己
    /// 重建的裸菜单项回调，只保留 `title`、`tag`、`action`：
    ///
    /// - `representedObject` 恒为 nil
    /// - `parentMenuTitle` 恒为 nil（`menu` 与 `parent` 都取不到，二三级子菜单同样）
    /// - `identifier` 被覆写为 action selector 名
    ///
    /// 往返测试必须用这个保真度构造输入，否则测的是理想输入，测不到真实路由。
    public static func finderObserved(title: String, tag: Int) -> MenuItemFields {
        MenuItemFields(
            title: title,
            tag: tag,
            identifier: observedActionSelectorName,
            representedObject: nil,
            parentMenuTitle: nil
        )
    }
}

/// Finder 右键菜单的不可变快照。
///
/// **不变量**：构造菜单与反解点击必须使用同一份快照。描述树与身份索引在同一次初始化里
/// 产出，消除「按旧菜单点击、按新配置解析」的时间窗。
public struct FinderMenuSnapshot: Sendable {
    public let entries: [MenuEntry]
    public let publishStates: [String: ScriptPublishState]
    public let presentationMode: MenuPresentationMode
    public let applicationIcons: [String: Data]

    /// 通过 Publish State 过滤后真正会出现在菜单里的 Menu Entry。
    public let visibleEntries: [MenuEntry]
    /// 构造菜单用的描述树。
    public let descriptors: [FinderMenuItemDescriptor]

    private let scriptBackedEntries: [ScriptBackedMenuEntry]
    private let customItems: [MenuItemConfig]

    public static let empty = FinderMenuSnapshot(
        entries: [],
        publishStates: [:],
        presentationMode: .flat,
        applicationIcons: [:]
    )

    public init(
        entries: [MenuEntry],
        publishStates: [String: ScriptPublishState],
        presentationMode: MenuPresentationMode,
        applicationIcons: [String: Data]
    ) {
        self.entries = entries
        self.publishStates = publishStates
        self.presentationMode = presentationMode
        self.applicationIcons = applicationIcons

        let visibleEntries = FinderMenuPresenter.visibleEntries(
            entries: entries,
            publishStates: publishStates
        )
        self.visibleEntries = visibleEntries
        self.descriptors = FinderMenuDescriptorBuilder.descriptors(
            visibleEntries: visibleEntries,
            publishStates: publishStates,
            presentationMode: presentationMode,
            applicationIcons: applicationIcons
        )
        self.scriptBackedEntries = visibleEntries.flatMap(
            MenuEntryScriptPolicy.scriptBackedEntries
        )
        self.customItems = visibleEntries.compactMap { entry in
            guard case .custom(let config) = entry else { return nil }
            return config
        }
    }

    /// 从点击回传的字段反解 Script-Backed Entry。
    ///
    /// 当前沿用既有回退链以保持行为等价；哪些分支实际有效见 ADR-0004。
    public func scriptBackedEntry(for fields: MenuItemFields) -> ScriptBackedMenuEntry? {
        MenuItemResolver.scriptBackedEntry(
            in: scriptBackedEntries,
            customItems: customItems,
            representedObject: fields.representedObject,
            identifier: fields.identifier,
            tag: fields.tag,
            title: fields.title,
            parentMenuTitle: fields.parentMenuTitle
        )
    }

    /// 描述树里全部 script-backed 项，按 Finder 实测保真度展平成「点击」。
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
