import Foundation

/// 校验时允许触碰的外部世界。
///
/// 「这个 Menu Entry 有效吗」有两个答案，取决于谁在问：
///
/// - `.configurationOnly` —— 只看配置本身，**一次文件系统 IO 都不做**。发布门与
///   `FinderMenuSnapshot` 走这条：它们会在扩展进程里、每次右键被调用。
/// - `.filesystemAware` —— 额外检查配置指向的文件是否还在。设置界面走这条，
///   用户需要看到「模板文件不见了」。
///
/// 默认取 `.configurationOnly`：忘记传参的后果不对称 —— 设置界面漏传只是少一条提示，
/// 发布门漏传会让扩展进程每次右键做文件系统 IO。
public enum MenuEntryValidationEnvironment: Sendable {
    case configurationOnly
    case filesystemAware
}

/// 一次 Menu Entry 评估的结果。
///
/// 「这个条目产出哪些脚本」与「它哪里有问题」是同一个问题的两面，因此同时给出。
/// 分开问会让两侧各自演化 —— 设置界面曾因此对不会被发布的条目显示「就绪」。
public struct MenuEntryEvaluation: Hashable, Sendable {
    /// 本条目产出的 Script-Backed Entry。
    ///
    /// custom / composite 为 0 或 1 个；New File Menu 每个可执行模板一个；Built-in Entry 恒为空。
    ///
    /// 注意它随 environment 变化：`.filesystemAware` 下模板文件丢失的条目不会出现在这里。
    /// 需要「实际会被发布的集合」时必须用 `.configurationOnly`。
    public let scriptBacked: [ScriptBackedMenuEntry]
    public let issues: [MenuEntryIssue]

    /// 条目是否可用。
    ///
    /// 不从 `scriptBacked.isEmpty` 派生：Built-in Entry 没有脚本却是 Finder 里真实可见的
    /// 菜单项，派生会让它读成不可用。
    public let isExecutable: Bool

    /// 条目内部是否存在至少一个通过校验的子项。
    ///
    /// composite 是「可执行步骤」，New File Menu 是「可执行模板」，custom 与 Built-in Entry
    /// 没有子项因此恒为 false。两者的 ID 集合语义不同（步骤被写进同一个脚本，模板各自
    /// 就是一个脚本），所以这里只暴露状态阶梯真正需要的那个布尔量，不合并 ID 集合。
    ///
    /// 它与 `isExecutable` 会分叉：组合命令名称为空时条目不可执行（无脚本产出），
    /// 但步骤本身可能全都合法 —— 那是「部分可用」而不是「不可用」。
    public let hasExecutableChildren: Bool

    public init(
        scriptBacked: [ScriptBackedMenuEntry],
        issues: [MenuEntryIssue],
        isExecutable: Bool,
        hasExecutableChildren: Bool = false
    ) {
        self.scriptBacked = scriptBacked
        self.issues = issues
        self.isExecutable = isExecutable
        self.hasExecutableChildren = hasExecutableChildren
    }

    public var errors: [MenuEntryIssue] { issues.errors }
    public var warnings: [MenuEntryIssue] { issues.warnings }
    public var hasErrors: Bool { issues.hasErrors }
    public var hasWarnings: Bool { issues.hasWarnings }
}

/// Menu Entry 的评估入口。
///
/// 三种 kind 的规则是它的实现（`CustomCommandValidator` / `CompositeMenuItemValidator` /
/// `NewFileMenuValidator`，均为 internal），调用方不该知道它们存在。
public enum MenuEntryEvaluator: Sendable {
    public static func evaluate(
        _ entry: MenuEntry,
        environment: MenuEntryValidationEnvironment = .configurationOnly
    ) -> MenuEntryEvaluation {
        evaluate(entry, probe: environment.probe)
    }

    public static func evaluate(
        _ entries: [MenuEntry],
        environment: MenuEntryValidationEnvironment = .configurationOnly
    ) -> [ScriptBackedMenuEntry] {
        let probe = environment.probe
        return entries.flatMap { evaluate($0, probe: probe).scriptBacked }
    }

    static func evaluate(
        _ entry: MenuEntry,
        probe: MenuEntryFileProbe
    ) -> MenuEntryEvaluation {
        switch entry {
        case .builtIn(let item):
            return MenuEntryEvaluation(
                scriptBacked: [],
                issues: [],
                isExecutable: item.isEnabled
            )

        case .custom(let config):
            let validation = CustomCommandValidator.validate(
                config,
                appExists: probe.applicationExists
            )
            return MenuEntryEvaluation(
                scriptBacked: validation.isExecutable
                    ? [
                        ScriptBackedMenuEntry(
                            id: config.id.uuidString,
                            kind: .custom,
                            displayName: config.appName,
                            fingerprint: fingerprint(for: config),
                            source: .custom(id: config.id),
                            targetPolicy: config.executionMode == .currentDirectory
                                ? .containingDirectory
                                : .selectedPath
                        ),
                    ]
                    : [],
                issues: validation.issues,
                isExecutable: validation.isExecutable
            )

        case .composite(let config):
            let validation = CompositeMenuItemValidator.validate(config)
            return MenuEntryEvaluation(
                scriptBacked: validation.isExecutable
                    ? [
                        ScriptBackedMenuEntry(
                            id: config.id.uuidString,
                            kind: .composite,
                            displayName: config.name,
                            fingerprint: validation.fingerprint,
                            source: .composite(
                                id: config.id,
                                executableStepIDs: validation.executableStepIDs
                            ),
                            targetPolicy: .selectedPath
                        ),
                    ]
                    : [],
                issues: validation.issues,
                isExecutable: validation.isExecutable,
                hasExecutableChildren: !validation.executableStepIDs.isEmpty
            )

        case .newFile(let config):
            let validation = NewFileMenuValidator.validate(
                config,
                fileInfo: probe.templateFileInfo
            )
            let scriptBacked: [ScriptBackedMenuEntry] = validation.isExecutable
                ? config.templates.compactMap { template in
                    guard validation.executableTemplateIDs.contains(template.id),
                          let fingerprint = validation.fingerprintByTemplateID[template.id] else {
                        return nil
                    }
                    return ScriptBackedMenuEntry(
                        id: MenuEntryScriptPolicy.newFileScriptID(
                            menuID: config.id,
                            templateID: template.id
                        ),
                        kind: .newFileTemplate,
                        displayName: template.displayName,
                        fingerprint: fingerprint,
                        source: .newFileTemplate(menuID: config.id, templateID: template.id),
                        targetPolicy: .containingDirectory,
                        parentDisplayName: config.name
                    )
                }
                : []
            return MenuEntryEvaluation(
                scriptBacked: scriptBacked,
                issues: validation.issues,
                isExecutable: validation.isExecutable,
                hasExecutableChildren: !validation.executableTemplateIDs.isEmpty
            )
        }
    }

    static func fingerprint(for config: MenuItemConfig) -> String {
        ScriptFingerprint.make(fields: [
            "custom-v2",
            config.id.uuidString.lowercased(),
            config.appName,
            config.bundleId ?? "",
            config.appPath,
            config.customCommand ?? "",
            config.executionMode.rawValue,
            String(config.isEnabled),
        ])
    }
}

/// environment 解析出的文件系统探针。
///
/// 单独成型是为了让测试能注入固定的文件信息，而不必把探针形态暴露在公开接口上。
struct MenuEntryFileProbe: Sendable {
    let templateFileInfo: @Sendable (String) -> NewFileTemplateFileInfo?
    let applicationExists: @Sendable (String) -> Bool

    /// 不碰文件系统：只从路径字符串推断扩展名，目录判定恒为 false，应用一律视为存在。
    static let configurationOnly = MenuEntryFileProbe(
        templateFileInfo: { path in
            let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPath.isEmpty else { return nil }

            return NewFileTemplateFileInfo(
                isDirectory: false,
                pathExtension: URL(fileURLWithPath: trimmedPath).pathExtension
            )
        },
        applicationExists: { _ in true }
    )

    static let filesystem = MenuEntryFileProbe(
        templateFileInfo: { path in
            var isDirectory = ObjCBool(false)
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
                return nil
            }

            return NewFileTemplateFileInfo(
                isDirectory: isDirectory.boolValue,
                pathExtension: URL(fileURLWithPath: path).pathExtension
            )
        },
        applicationExists: { path in
            FileManager.default.fileExists(atPath: path)
        }
    )
}

extension MenuEntryValidationEnvironment {
    var probe: MenuEntryFileProbe {
        switch self {
        case .configurationOnly:
            return .configurationOnly
        case .filesystemAware:
            return .filesystem
        }
    }
}
