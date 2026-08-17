import Foundation

struct CustomCommandValidationResult: Hashable, Sendable {
    let issues: [MenuEntryIssue]
    let isExecutable: Bool

    var errors: [MenuEntryIssue] { issues.errors }
    var warnings: [MenuEntryIssue] { issues.warnings }
    var hasErrors: Bool { issues.hasErrors }
    var hasWarnings: Bool { issues.hasWarnings }
}

/// custom 项的规则。`MenuEntryEvaluator` 的实现，调用方走 evaluator。
enum CustomCommandValidator: Sendable {
    static let maxNameLength = 80
    static let maxCommandLength = 2_000

    static func validate(
        _ item: MenuItemConfig,
        appExists: (String) -> Bool = { _ in true }
    ) -> CustomCommandValidationResult {
        var issues: [MenuEntryIssue] = []
        let trimmedName = item.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAppPath = item.appPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = item.customCommand ?? ""
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            issues.append(
                issue(
                    .blankName,
                    .error,
                    "命令名称不能为空。"
                )
            )
        }

        if item.appName.count > maxNameLength {
            issues.append(
                issue(
                    .nameTooLong,
                    .error,
                    "命令名称不能超过 \(maxNameLength) 个字符。"
                )
            )
        }

        if item.executionMode == .selectedPath && trimmedAppPath.isEmpty {
            issues.append(
                issue(
                    .blankAppPath,
                    .error,
                    "目标路径模式需要应用路径。"
                )
            )
        }

        // 只在 .filesystemAware 下成立 —— 发布门必须继续为「应用临时不在」的条目编译脚本，
        // 否则用户卸载一次应用就会丢掉 .scpt。
        if item.executionMode == .selectedPath,
           !trimmedAppPath.isEmpty,
           !appExists(trimmedAppPath) {
            issues.append(
                issue(
                    .applicationMissing,
                    .error,
                    "找不到应用，它可能已被移动或卸载。",
                    detail: trimmedAppPath
                )
            )
        }

        if item.executionMode == .currentDirectory && trimmedCommand.isEmpty {
            issues.append(
                issue(
                    .blankCommand,
                    .error,
                    "命令不能为空。"
                )
            )
        }

        if command.count > maxCommandLength {
            issues.append(
                issue(
                    .commandTooLong,
                    .error,
                    "命令不能超过 \(maxCommandLength) 个字符。"
                )
            )
        }

        if item.executionMode == .currentDirectory {
            for placeholder in ["{path}", "{app}", "{bundle}"] where command.contains(placeholder) {
                issues.append(
                    issue(
                        .unsupportedPlaceholder,
                        .warning,
                        "当前目录模式不会展开占位符。",
                        detail: placeholder
                    )
                )
            }
        }

        for pattern in ShellCommandSafety.dangerousPatterns(in: command) {
            issues.append(
                issue(
                    .dangerousCommandPattern,
                    .warning,
                    "命令包含潜在危险的 shell 片段。",
                    detail: pattern
                )
            )
        }

        return CustomCommandValidationResult(
            issues: issues,
            isExecutable: item.isEnabled && !issues.hasErrors
        )
    }

    private static func issue(
        _ code: MenuEntryIssueCode,
        _ severity: MenuEntryIssueSeverity,
        _ message: String,
        detail: String? = nil
    ) -> MenuEntryIssue {
        MenuEntryIssue(
            code: code,
            severity: severity,
            message: message,
            detail: detail
        )
    }
}
