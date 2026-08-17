import Foundation

public enum MenuEntryIssueSeverity: String, Hashable, Sendable {
    case error
    case warning
}

/// Menu Entry 校验问题的分类。
///
/// 三个 kind 的规则合并而来，rawValue 逐字沿用合并前的值。
/// `dangerousCommandPattern` 是 custom 与 composite 共有的一条。
///
/// 目前没有任何生产代码按 code 分支 —— 它服务于测试与 issue 的身份拼装。
/// 出现按 code 分支的消费者时，再考虑合并同义项（五组「名称为空」、五组「名称过长」）。
public enum MenuEntryIssueCode: String, Hashable, Sendable {
    // MARK: custom

    case blankName
    case nameTooLong
    case blankAppPath
    case blankCommand
    case commandTooLong
    case unsupportedPlaceholder
    /// 配置指向的应用不在了。只在 `.filesystemAware` 下产生。
    case applicationMissing

    // MARK: custom + composite 共有

    case dangerousCommandPattern

    // MARK: composite

    case blankCompositeName
    case compositeNameTooLong
    case noSteps
    case tooManySteps
    case blankStepName
    case stepNameTooLong
    case blankCommandTemplate
    case commandTemplateTooLong
    case appStepMissingAppPath
    case appStepMissingBundleId
    case appStepMissingAppPlaceholder
    case shellStepContainsAppPlaceholder
    case missingPathPlaceholder

    // MARK: newFile

    case blankMenuName
    case menuNameTooLong
    case noTemplates
    case blankTemplateName
    case templateNameTooLong
    case duplicateTemplateName
    case blankBaseName
    case baseNameContainsSeparator
    case blankExtension
    case extensionContainsDot
    case extensionContainsInvalidCharacters
    case textContentTooLong
    case missingTemplatePath
    case templatePathIsDirectory
    case templatePathMissing
    case templateExtensionMismatch
}

/// 一条 Menu Entry 校验问题。
///
/// `childID` 指向条目内部的子项 —— composite 的步骤或 New File Menu 的模板；
/// 条目级问题为 nil。`detail` 是参与身份拼装的区分性字符串（危险 shell 片段、
/// 不被支持的占位符、重复的模板名、不匹配的扩展名），合并自此前的 `pattern` 与 `detail`。
public struct MenuEntryIssue: Identifiable, Hashable, Sendable {
    public let id: String
    public let code: MenuEntryIssueCode
    public let severity: MenuEntryIssueSeverity
    public let message: String
    public let childID: UUID?
    public let detail: String?

    public init(
        code: MenuEntryIssueCode,
        severity: MenuEntryIssueSeverity,
        message: String,
        childID: UUID? = nil,
        detail: String? = nil
    ) {
        self.code = code
        self.severity = severity
        self.message = message
        self.childID = childID
        self.detail = detail
        id = [
            childID?.uuidString ?? "entry",
            code.rawValue,
            detail ?? "",
        ].joined(separator: ":")
    }
}

extension Array where Element == MenuEntryIssue {
    public var errors: [MenuEntryIssue] {
        filter { $0.severity == .error }
    }

    public var warnings: [MenuEntryIssue] {
        filter { $0.severity == .warning }
    }

    public var hasErrors: Bool {
        contains { $0.severity == .error }
    }

    public var hasWarnings: Bool {
        contains { $0.severity == .warning }
    }
}
