import Foundation

public enum FinderMenuEntryKind: String, Codable, Hashable, Sendable {
    case builtIn
    case customApp
    case customCommand
    case composite
    case newFile
}

public enum FinderMenuEntryStatusKind: String, Codable, Hashable, Sendable {
    case ready
    case syncing
    case failed
    case unavailable
    case partiallyAvailable
    case warning
    case disabled
    case command
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
        publishStates: [String: ScriptPublishState],
        appExists: @Sendable (String) -> Bool = { path in
            FileManager.default.fileExists(atPath: path)
        }
    ) -> [FinderMenuEntrySummary] {
        entries.enumerated().map { index, entry in
            summary(
                for: entry,
                position: index + 1,
                total: entries.count,
                publishStates: publishStates,
                appExists: appExists
            )
        }
    }

    public static func summary(
        for entry: MenuEntry,
        position: Int,
        total: Int,
        publishStates: [String: ScriptPublishState],
        appExists: @Sendable (String) -> Bool = { path in
            FileManager.default.fileExists(atPath: path)
        }
    ) -> FinderMenuEntrySummary {
        switch entry {
        case .builtIn(let item):
            return builtInSummary(item, entryID: entry.id, position: position, total: total)
        case .custom(let config):
            return customSummary(config, position: position, total: total, appExists: appExists)
        case .composite(let config):
            return compositeSummary(
                config,
                publishState: publishStates[config.id.uuidString],
                position: position,
                total: total
            )
        case .newFile(let config):
            return newFileSummary(
                config,
                publishStates: publishStates,
                position: position,
                total: total
            )
        }
    }

    private static func builtInSummary(
        _ item: BuiltInMenuItem,
        entryID: String,
        position: Int,
        total: Int
    ) -> FinderMenuEntrySummary {
        FinderMenuEntrySummary(
            id: entryID,
            title: item.displayName,
            subtitle: "系统菜单项",
            kind: .builtIn,
            typeLabel: "系统",
            symbolName: item.iconName,
            appPath: nil,
            isEnabled: item.isEnabled,
            position: position,
            total: total,
            statusKind: item.isEnabled ? .system : .disabled,
            statusText: item.isEnabled ? "系统" : "已停用",
            statusDetail: item.isEnabled ? "内置 Finder 菜单功能" : "此内置菜单项已停用",
            allowsDelete: false
        )
    }

    private static func customSummary(
        _ config: MenuItemConfig,
        position: Int,
        total: Int,
        appExists: @Sendable (String) -> Bool
    ) -> FinderMenuEntrySummary {
        let isShellCommand = config.executionMode == .currentDirectory
        let exists = isShellCommand || appExists(config.appPath)
        let status: (FinderMenuEntryStatusKind, String, String?)

        if !config.isEnabled {
            status = (.disabled, "已停用", "此菜单项已停用")
        } else if isShellCommand {
            status = (.command, "命令", config.customCommand ?? "自定义命令")
        } else if exists {
            status = (.ready, "就绪", config.appPath)
        } else {
            status = (.unavailable, "未找到", config.appPath)
        }

        return FinderMenuEntrySummary(
            id: config.id.uuidString,
            title: config.appName,
            subtitle: isShellCommand ? config.executionMode.displayName : config.appPath,
            kind: isShellCommand ? .customCommand : .customApp,
            typeLabel: isShellCommand ? "命令" : "应用",
            symbolName: isShellCommand ? "terminal" : nil,
            appPath: isShellCommand ? nil : config.appPath,
            isEnabled: config.isEnabled,
            position: position,
            total: total,
            statusKind: status.0,
            statusText: status.1,
            statusDetail: status.2,
            allowsDelete: true
        )
    }

    private static func compositeSummary(
        _ config: CompositeMenuItemConfig,
        publishState: ScriptPublishState?,
        position: Int,
        total: Int
    ) -> FinderMenuEntrySummary {
        let validation = CompositeMenuItemValidator.validate(config)
        let status: (FinderMenuEntryStatusKind, String, String?)

        if !config.isEnabled {
            status = (.disabled, "已停用", "此组合命令已停用")
        } else if validation.hasErrors && validation.executableStepIDs.isEmpty {
            status = (.unavailable, "不可用", validation.errors.first?.message)
        } else if validation.hasErrors {
            status = (.partiallyAvailable, "部分可用", validation.errors.first?.message)
        } else if validation.hasWarnings {
            status = (.warning, "有警告", validation.warnings.first?.message)
        } else if let publishState {
            if publishState.fingerprint != validation.fingerprint {
                status = (.syncing, "同步中", "脚本指纹已变化，等待重新同步")
            } else {
                switch publishState.status {
                case .current:
                    status = (.ready, "就绪", "脚本已同步")
                case .compileFailed:
                    status = (.failed, "同步失败", publishState.errorSummary)
                }
            }
        } else {
            status = (.syncing, "同步中", "等待脚本同步")
        }

        return FinderMenuEntrySummary(
            id: config.id.uuidString,
            title: config.name,
            subtitle: "\(config.steps.count) 个步骤",
            kind: .composite,
            typeLabel: "组合命令",
            symbolName: config.iconName ?? "rectangle.stack.badge.play",
            appPath: nil,
            isEnabled: config.isEnabled,
            position: position,
            total: total,
            statusKind: status.0,
            statusText: status.1,
            statusDetail: status.2,
            allowsDelete: true
        )
    }

    private static func newFileSummary(
        _ config: NewFileMenuConfig,
        publishStates: [String: ScriptPublishState],
        position: Int,
        total: Int
    ) -> FinderMenuEntrySummary {
        let status = NewFileMenuStatusResolver.resolve(
            config: config,
            publishStates: publishStates
        )

        return FinderMenuEntrySummary(
            id: config.id.uuidString,
            title: config.name,
            subtitle: "\(config.templates.count) 个模板",
            kind: .newFile,
            typeLabel: "新建文件",
            symbolName: config.iconName ?? "document.badge.plus",
            appPath: nil,
            isEnabled: config.isEnabled,
            position: position,
            total: total,
            statusKind: statusKind(for: status.kind),
            statusText: status.displayName,
            statusDetail: newFileDetail(for: config, status: status),
            allowsDelete: false
        )
    }

    private static func statusKind(for status: NewFileMenuStatusKind) -> FinderMenuEntryStatusKind {
        switch status {
        case .disabled:
            return .disabled
        case .unavailable:
            return .unavailable
        case .partiallyAvailable:
            return .partiallyAvailable
        case .warning:
            return .warning
        case .syncing:
            return .syncing
        case .ready:
            return .ready
        }
    }

    private static func newFileDetail(
        for config: NewFileMenuConfig,
        status: NewFileMenuStatus
    ) -> String? {
        if config.templates.isEmpty {
            return "暂无模板"
        }
        let names = config.templates.prefix(3).map(\.displayName).joined(separator: "、")
        return "\(status.displayName)：\(names)"
    }
}
