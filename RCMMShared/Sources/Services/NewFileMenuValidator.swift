import Foundation

struct NewFileValidationResult: Hashable, Sendable {
    let issues: [MenuEntryIssue]
    let executableTemplateIDs: Set<UUID>
    let fingerprintByTemplateID: [UUID: String]
    let isExecutable: Bool

    var errors: [MenuEntryIssue] { issues.errors }
    var warnings: [MenuEntryIssue] { issues.warnings }
    var hasErrors: Bool { issues.hasErrors }
    var hasWarnings: Bool { issues.hasWarnings }
}

/// New File Menu 的规则。`MenuEntryEvaluator` 的实现，调用方走 evaluator。
///
/// `executableTemplateIDs` 是「哪些模板**本身就是**一个脚本」—— 与 composite 的
/// `executableStepIDs`（哪些步骤被写进同一个脚本）语义不同。
enum NewFileMenuValidator: Sendable {
    static let maxMenuNameLength = 80
    static let maxTemplateNameLength = 40
    static let maxTextContentLength = 100_000

    /// 读文件系统的默认模式。扩展进程与发布门必须走带 `fileInfo` 的重载。
    static func validate(_ menu: NewFileMenuConfig) -> NewFileValidationResult {
        validate(menu, fileInfo: MenuEntryFileProbe.filesystem.templateFileInfo)
    }

    static func validate(
        _ menu: NewFileMenuConfig,
        fileInfo: (String) -> NewFileTemplateFileInfo?
    ) -> NewFileValidationResult {
        var issues: [MenuEntryIssue] = []
        var hasParentBlockingError = false

        let trimmedName = menu.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            issues.append(
                issue(.blankMenuName, .error, "新建菜单名称不能为空。")
            )
            hasParentBlockingError = true
        }

        if menu.name.count > maxMenuNameLength {
            issues.append(
                issue(.menuNameTooLong, .error, "新建菜单名称不能超过 \(maxMenuNameLength) 个字符。")
            )
            hasParentBlockingError = true
        }

        if menu.templates.isEmpty {
            issues.append(
                issue(.noTemplates, .error, "新建菜单至少需要一个模板。")
            )
            hasParentBlockingError = true
        }

        let enabledNames = menu.templates
            .filter(\.isEnabled)
            .map { $0.displayName.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let duplicateNames = Set(
            Dictionary(grouping: enabledNames, by: { $0 })
                .filter { $0.value.count > 1 }
                .map(\.key)
        )

        var executableTemplateIDs = Set<UUID>()
        var fingerprintByTemplateID: [UUID: String] = [:]

        for template in menu.templates {
            let templateIssues = validateTemplate(
                template,
                duplicateNames: duplicateNames,
                fileInfo: fileInfo
            )
            issues.append(contentsOf: templateIssues)

            let templateHasBlockingError = templateIssues.hasErrors
            if template.isEnabled && !templateHasBlockingError {
                executableTemplateIDs.insert(template.id)
                fingerprintByTemplateID[template.id] = fingerprint(for: menu, template: template)
            }
        }

        return NewFileValidationResult(
            issues: issues,
            executableTemplateIDs: executableTemplateIDs,
            fingerprintByTemplateID: fingerprintByTemplateID,
            isExecutable: menu.isEnabled && !hasParentBlockingError && !executableTemplateIDs.isEmpty
        )
    }

    static func fingerprint(
        for menu: NewFileMenuConfig,
        template: NewFileTemplateConfig
    ) -> String {
        ScriptFingerprint.make(fields: [
            "new-file-v1",
            menu.id.uuidString.lowercased(),
            menu.name,
            menu.iconName ?? "",
            String(menu.isEnabled),
            template.id.uuidString.lowercased(),
            template.displayName,
            template.baseName,
            template.fileExtension,
            template.creationMode.rawValue,
            template.templatePath ?? "",
            template.templateFingerprint?.path ?? "",
            String(template.templateFingerprint?.fileSize ?? 0),
            String(template.templateFingerprint?.modificationTime ?? 0),
            template.initialContent ?? "",
            String(template.isEnabled),
        ])
    }

    private static func validateTemplate(
        _ template: NewFileTemplateConfig,
        duplicateNames: Set<String>,
        fileInfo: (String) -> NewFileTemplateFileInfo?
    ) -> [MenuEntryIssue] {
        guard template.isEnabled else {
            return []
        }

        var issues: [MenuEntryIssue] = []
        let trimmedName = template.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseName = template.baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExtension = template.fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            issues.append(
                issue(.blankTemplateName, .error, "模板名称不能为空。", childID: template.id)
            )
        }

        if template.displayName.count > maxTemplateNameLength {
            issues.append(
                issue(
                    .templateNameTooLong,
                    .error,
                    "模板名称不能超过 \(maxTemplateNameLength) 个字符。",
                    childID: template.id
                )
            )
        }

        if duplicateNames.contains(trimmedName) {
            issues.append(
                issue(
                    .duplicateTemplateName,
                    .error,
                    "同一个新建菜单下不能有重复的模板菜单名。",
                    childID: template.id,
                    detail: trimmedName
                )
            )
        }

        if trimmedBaseName.isEmpty {
            issues.append(
                issue(.blankBaseName, .error, "基础文件名不能为空。", childID: template.id)
            )
        }

        if containsPathSeparator(trimmedBaseName) {
            issues.append(
                issue(
                    .baseNameContainsSeparator,
                    .error,
                    "基础文件名不能包含路径分隔符。",
                    childID: template.id
                )
            )
        }

        if trimmedExtension.isEmpty {
            issues.append(
                issue(.blankExtension, .error, "文件扩展名不能为空。", childID: template.id)
            )
        }

        if trimmedExtension.contains(".") {
            issues.append(
                issue(.extensionContainsDot, .error, "扩展名不需要包含点号。", childID: template.id)
            )
        }

        if containsInvalidExtensionCharacters(trimmedExtension) {
            issues.append(
                issue(
                    .extensionContainsInvalidCharacters,
                    .error,
                    "扩展名不能包含空白、路径分隔符或空字符。",
                    childID: template.id
                )
            )
        }

        if template.creationMode == .textContent,
           let initialContent = template.initialContent,
           initialContent.utf8.count > maxTextContentLength {
            issues.append(
                issue(
                    .textContentTooLong,
                    .error,
                    "默认文本内容不能超过 \(maxTextContentLength) 字节。",
                    childID: template.id
                )
            )
        }

        if template.creationMode == .copyTemplate {
            let trimmedPath = template.templatePath?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmedPath.isEmpty {
                issues.append(
                    issue(.missingTemplatePath, .error, "复制模板模式需要模板文件路径。", childID: template.id)
                )
            } else if let info = fileInfo(trimmedPath) {
                if info.isDirectory {
                    issues.append(
                        issue(.templatePathIsDirectory, .error, "模板路径不能是目录。", childID: template.id)
                    )
                }
                if !info.pathExtension.isEmpty,
                   info.pathExtension != trimmedExtension {
                    issues.append(
                        issue(
                            .templateExtensionMismatch,
                            .warning,
                            "模板文件扩展名和配置扩展名不一致。",
                            childID: template.id,
                            detail: info.pathExtension
                        )
                    )
                }
            } else {
                issues.append(
                    issue(.templatePathMissing, .error, "模板文件不存在或无法读取。", childID: template.id)
                )
            }
        }

        return issues
    }

    private static func issue(
        _ code: MenuEntryIssueCode,
        _ severity: MenuEntryIssueSeverity,
        _ message: String,
        childID: UUID? = nil,
        detail: String? = nil
    ) -> MenuEntryIssue {
        MenuEntryIssue(
            code: code,
            severity: severity,
            message: message,
            childID: childID,
            detail: detail
        )
    }

    private static func containsPathSeparator(_ value: String) -> Bool {
        value.contains("/") || value.contains("\0")
    }

    private static func containsInvalidExtensionCharacters(_ value: String) -> Bool {
        containsPathSeparator(value) || value.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
    }
}

public struct NewFileTemplateFileInfo: Hashable, Sendable {
    public let isDirectory: Bool
    public let pathExtension: String

    public init(isDirectory: Bool, pathExtension: String) {
        self.isDirectory = isDirectory
        self.pathExtension = pathExtension
    }
}
