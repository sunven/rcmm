import Foundation

public enum CustomCommandValidationIssueSeverity: String, Codable, Hashable, Sendable {
    case error
    case warning
}

public enum CustomCommandValidationIssueCode: String, Codable, Hashable, Sendable {
    case blankName
    case nameTooLong
    case blankAppPath
    case blankCommand
    case commandTooLong
    case unsupportedPlaceholder
    case dangerousCommandPattern
}

public struct CustomCommandValidationIssue: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let code: CustomCommandValidationIssueCode
    public let severity: CustomCommandValidationIssueSeverity
    public let message: String
    public let pattern: String?

    public init(
        code: CustomCommandValidationIssueCode,
        severity: CustomCommandValidationIssueSeverity,
        message: String,
        pattern: String? = nil
    ) {
        self.code = code
        self.severity = severity
        self.message = message
        self.pattern = pattern
        id = [
            code.rawValue,
            pattern ?? "",
        ].joined(separator: ":")
    }
}

public struct CustomCommandValidationResult: Codable, Hashable, Sendable {
    public let issues: [CustomCommandValidationIssue]
    public let isExecutable: Bool

    public var errors: [CustomCommandValidationIssue] {
        issues.filter { $0.severity == .error }
    }

    public var warnings: [CustomCommandValidationIssue] {
        issues.filter { $0.severity == .warning }
    }

    public var hasErrors: Bool {
        !errors.isEmpty
    }

    public var hasWarnings: Bool {
        !warnings.isEmpty
    }
}

public enum CustomCommandValidator: Sendable {
    public static let maxNameLength = 80
    public static let maxCommandLength = 2_000

    public static func validate(_ item: MenuItemConfig) -> CustomCommandValidationResult {
        var issues: [CustomCommandValidationIssue] = []
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
                        pattern: placeholder
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
                    pattern: pattern
                )
            )
        }

        return CustomCommandValidationResult(
            issues: issues,
            isExecutable: item.isEnabled && !issues.contains { $0.severity == .error }
        )
    }

    private static func issue(
        _ code: CustomCommandValidationIssueCode,
        _ severity: CustomCommandValidationIssueSeverity,
        _ message: String,
        pattern: String? = nil
    ) -> CustomCommandValidationIssue {
        CustomCommandValidationIssue(
            code: code,
            severity: severity,
            message: message,
            pattern: pattern
        )
    }
}
