import Foundation

public enum FinderMenuEntryKind: String, Codable, Hashable, Sendable {
    case builtIn
    case customApp
    case customCommand
    case composite
    case newFile
}

/// 徽章状态。与 DESIGN.md「Finder Menu Row」的六个状态对应，外加 `.system`
/// 供没有脚本、也就没有发布状态的 Built-in Entry 使用。
///
/// 不含类型标签 —— 「命令」「系统」这类描述属于 `FinderMenuEntrySummary.typeLabel`。
public enum FinderMenuEntryStatusKind: String, Codable, Hashable, Sendable {
    case ready
    case syncing
    case failed
    case unavailable
    case partiallyAvailable
    case warning
    case disabled
    case system
}

public struct FinderMenuEntrySummary: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let kind: FinderMenuEntryKind
    public let typeLabel: String
    public let symbolName: String?
    public let appPath: String?
    public let isEnabled: Bool
    public let position: Int
    public let total: Int
    public let statusKind: FinderMenuEntryStatusKind
    public let statusText: String
    public let statusDetail: String?
    public let allowsDelete: Bool

    public init(
        id: String,
        title: String,
        subtitle: String?,
        kind: FinderMenuEntryKind,
        typeLabel: String,
        symbolName: String?,
        appPath: String?,
        isEnabled: Bool,
        position: Int,
        total: Int,
        statusKind: FinderMenuEntryStatusKind,
        statusText: String,
        statusDetail: String?,
        allowsDelete: Bool
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.typeLabel = typeLabel
        self.symbolName = symbolName
        self.appPath = appPath
        self.isEnabled = isEnabled
        self.position = position
        self.total = total
        self.statusKind = statusKind
        self.statusText = statusText
        self.statusDetail = statusDetail
        self.allowsDelete = allowsDelete
    }
}

public enum FinderMenuEntrySummaryBuilder: Sendable {
    public static func summaries(
        for entries: [MenuEntry],
        publishStates: [String: ScriptPublishState]
    ) -> [FinderMenuEntrySummary] {
        entries.enumerated().map { index, entry in
            summary(
                for: entry,
                position: index + 1,
                total: entries.count,
                publishStates: publishStates
            )
        }
    }

    public static func summary(
        for entry: MenuEntry,
        position: Int,
        total: Int,
        publishStates: [String: ScriptPublishState]
    ) -> FinderMenuEntrySummary {
        summary(
            for: entry,
            position: position,
            total: total,
            publishStates: publishStates,
            // 设置界面要让用户看见「应用没了」「模板文件没了」，因此走 filesystemAware。
            evaluation: MenuEntryEvaluator.evaluate(entry, environment: .filesystemAware)
        )
    }

    static func summary(
        for entry: MenuEntry,
        position: Int,
        total: Int,
        publishStates: [String: ScriptPublishState],
        evaluation: MenuEntryEvaluation
    ) -> FinderMenuEntrySummary {
        let status = MenuEntryStatusResolver.status(
            for: entry,
            evaluation: evaluation,
            publishStates: publishStates
        )
        let presentation = presentation(for: entry)

        return FinderMenuEntrySummary(
            id: entry.id,
            title: entry.displayName,
            subtitle: presentation.subtitle,
            kind: presentation.kind,
            typeLabel: presentation.typeLabel,
            symbolName: presentation.symbolName,
            appPath: presentation.appPath,
            isEnabled: entry.isEnabled,
            position: position,
            total: total,
            statusKind: status.kind,
            statusText: status.text,
            statusDetail: presentation.statusDetail(for: status),
            allowsDelete: presentation.allowsDelete
        )
    }

    // MARK: - 展示信息

    /// 与状态阶梯正交的部分：条目长什么样、归为哪一类、能不能删。
    private struct Presentation {
        let kind: FinderMenuEntryKind
        let typeLabel: String
        let subtitle: String?
        let symbolName: String?
        let appPath: String?
        let allowsDelete: Bool
        /// 就绪时用条目自己的信息替换阶梯给的通用文案；其余状态一律用阶梯的。
        let readyDetail: String?

        func statusDetail(for status: MenuEntryStatus) -> String? {
            status.kind == .ready ? (readyDetail ?? status.detail) : status.detail
        }
    }

    private static func presentation(for entry: MenuEntry) -> Presentation {
        switch entry {
        case .builtIn(let item):
            return Presentation(
                kind: .builtIn,
                typeLabel: "系统",
                subtitle: "系统菜单项",
                symbolName: item.iconName,
                appPath: nil,
                allowsDelete: false,
                readyDetail: nil
            )

        case .custom(let config):
            let isShellCommand = config.executionMode == .currentDirectory
            return Presentation(
                kind: isShellCommand ? .customCommand : .customApp,
                typeLabel: isShellCommand ? "命令" : "应用",
                subtitle: isShellCommand ? config.executionMode.displayName : config.appPath,
                symbolName: isShellCommand ? "terminal" : nil,
                appPath: isShellCommand ? nil : config.appPath,
                allowsDelete: true,
                readyDetail: isShellCommand
                    ? (config.customCommand ?? "自定义命令")
                    : config.appPath
            )

        case .composite(let config):
            return Presentation(
                kind: .composite,
                typeLabel: "组合命令",
                subtitle: "\(config.steps.count) 个步骤",
                symbolName: config.iconName ?? "rectangle.stack.badge.play",
                appPath: nil,
                allowsDelete: true,
                readyDetail: nil
            )

        case .newFile(let config):
            return Presentation(
                kind: .newFile,
                typeLabel: "新建文件",
                subtitle: "\(config.templates.count) 个模板",
                symbolName: config.iconName ?? "document.badge.plus",
                appPath: nil,
                allowsDelete: false,
                readyDetail: newFileReadyDetail(for: config)
            )
        }
    }

    private static func newFileReadyDetail(for config: NewFileMenuConfig) -> String? {
        guard !config.templates.isEmpty else {
            return "暂无模板"
        }
        return config.templates.prefix(3).map(\.displayName).joined(separator: "、")
    }
}
