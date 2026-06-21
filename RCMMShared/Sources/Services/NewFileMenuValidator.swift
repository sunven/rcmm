import Foundation

public enum NewFileValidationIssueSeverity: String, Codable, Hashable, Sendable {
    case error
    case warning
}

public enum NewFileValidationIssueCode: String, Codable, Hashable, Sendable {
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

public struct NewFileValidationIssue: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let code: NewFileValidationIssueCode
    public let severity: NewFileValidationIssueSeverity
    public let message: String
    public let templateID: UUID?
    public let detail: String?

    public init(
        code: NewFileValidationIssueCode,
        severity: NewFileValidationIssueSeverity,
        message: String,
        templateID: UUID? = nil,
        detail: String? = nil
    ) {
        self.code = code
        self.severity = severity
        self.message = message
        self.templateID = templateID
        self.detail = detail
        id = [
            templateID?.uuidString ?? "newFile",
            code.rawValue,
            detail ?? "",
        ].joined(separator: ":")
    }
}

public struct NewFileValidationResult: Codable, Hashable, Sendable {
    public let issues: [NewFileValidationIssue]
    public let executableTemplateIDs: Set<UUID>
    public let fingerprintByTemplateID: [UUID: String]
    public let isExecutable: Bool

    public var errors: [NewFileValidationIssue] {
        issues.filter { $0.severity == .error }
    }

    public var warnings: [NewFileValidationIssue] {
        issues.filter { $0.severity == .warning }
    }

    public var hasErrors: Bool {
        !errors.isEmpty
    }

    public var hasWarnings: Bool {
        !warnings.isEmpty
    }
}

public enum NewFileMenuValidator: Sendable {
    public static let maxMenuNameLength = 80
    public static let maxTemplateNameLength = 40
    public static let maxTextContentLength = 100_000

    public static func validate(_ menu: NewFileMenuConfig) -> NewFileValidationResult {
        validate(menu, fileInfo: defaultFileInfo)
    }

    public static func validate(
        _ menu: NewFileMenuConfig,
        fileInfo: (String) -> NewFileTemplateFileInfo?
    ) -> NewFileValidationResult {
        var issues: [NewFileValidationIssue] = []
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

            let templateHasBlockingError = templateIssues.contains { $0.severity == .error }
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

    public static func fingerprint(
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
    ) -> [NewFileValidationIssue] {
        guard template.isEnabled else {
            return []
        }

        var issues: [NewFileValidationIssue] = []
        let trimmedName = template.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseName = template.baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExtension = template.fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            issues.append(
                issue(.blankTemplateName, .error, "模板名称不能为空。", templateID: template.id)
            )
        }

        if template.displayName.count > maxTemplateNameLength {
            issues.append(
                issue(
                    .templateNameTooLong,
                    .error,
                    "模板名称不能超过 \(maxTemplateNameLength) 个字符。",
                    templateID: template.id
                )
            )
        }

        if duplicateNames.contains(trimmedName) {
            issues.append(
                issue(
                    .duplicateTemplateName,
                    .error,
                    "同一个新建菜单下不能有重复的模板菜单名。",
                    templateID: template.id,
                    detail: trimmedName
                )
            )
        }

        if trimmedBaseName.isEmpty {
            issues.append(
                issue(.blankBaseName, .error, "基础文件名不能为空。", templateID: template.id)
            )
        }

        if containsPathSeparator(trimmedBaseName) {
            issues.append(
                issue(
                    .baseNameContainsSeparator,
                    .error,
                    "基础文件名不能包含路径分隔符。",
                    templateID: template.id
                )
            )
        }

        if trimmedExtension.isEmpty {
            issues.append(
                issue(.blankExtension, .error, "文件扩展名不能为空。", templateID: template.id)
            )
        }

        if trimmedExtension.contains(".") {
            issues.append(
                issue(.extensionContainsDot, .error, "扩展名不需要包含点号。", templateID: template.id)
            )
        }

        if containsInvalidExtensionCharacters(trimmedExtension) {
            issues.append(
                issue(
                    .extensionContainsInvalidCharacters,
                    .error,
                    "扩展名不能包含空白、路径分隔符或空字符。",
                    templateID: template.id
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
                    templateID: template.id
                )
            )
        }

        if template.creationMode == .copyTemplate {
            let trimmedPath = template.templatePath?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmedPath.isEmpty {
                issues.append(
                    issue(.missingTemplatePath, .error, "复制模板模式需要模板文件路径。", templateID: template.id)
                )
            } else if let info = fileInfo(trimmedPath) {
                if info.isDirectory {
                    issues.append(
                        issue(.templatePathIsDirectory, .error, "模板路径不能是目录。", templateID: template.id)
                    )
                }
                if !info.pathExtension.isEmpty,
                   info.pathExtension != trimmedExtension {
                    issues.append(
                        issue(
                            .templateExtensionMismatch,
                            .warning,
                            "模板文件扩展名和配置扩展名不一致。",
                            templateID: template.id,
                            detail: info.pathExtension
                        )
                    )
                }
            } else {
                issues.append(
                    issue(.templatePathMissing, .error, "模板文件不存在或无法读取。", templateID: template.id)
                )
            }
        }

        return issues
    }

    private static func issue(
        _ code: NewFileValidationIssueCode,
        _ severity: NewFileValidationIssueSeverity,
        _ message: String,
        templateID: UUID? = nil,
        detail: String? = nil
    ) -> NewFileValidationIssue {
        NewFileValidationIssue(
            code: code,
            severity: severity,
            message: message,
            templateID: templateID,
            detail: detail
        )
    }

    private static func containsPathSeparator(_ value: String) -> Bool {
        value.contains("/") || value.contains("\0")
    }

    private static func containsInvalidExtensionCharacters(_ value: String) -> Bool {
        containsPathSeparator(value) || value.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
    }

    private static func defaultFileInfo(path: String) -> NewFileTemplateFileInfo? {
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        return NewFileTemplateFileInfo(
            isDirectory: isDirectory.boolValue,
            pathExtension: url.pathExtension
        )
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
