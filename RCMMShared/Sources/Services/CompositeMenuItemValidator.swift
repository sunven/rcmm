import Foundation

public enum CompositeValidationIssueSeverity: String, Codable, Hashable, Sendable {
    case error
    case warning
}

public enum CompositeValidationIssueCode: String, Codable, Hashable, Sendable {
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
    case dangerousCommandPattern
}

public struct CompositeValidationIssue: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let code: CompositeValidationIssueCode
    public let severity: CompositeValidationIssueSeverity
    public let message: String
    public let stepID: UUID?
    public let pattern: String?

    public init(
        code: CompositeValidationIssueCode,
        severity: CompositeValidationIssueSeverity,
        message: String,
        stepID: UUID? = nil,
        pattern: String? = nil
    ) {
        self.code = code
        self.severity = severity
        self.message = message
        self.stepID = stepID
        self.pattern = pattern
        id = [
            stepID?.uuidString ?? "composite",
            code.rawValue,
            pattern ?? "",
        ].joined(separator: ":")
    }
}

public struct CompositeValidationResult: Codable, Hashable, Sendable {
    public let issues: [CompositeValidationIssue]
    public let executableStepIDs: Set<UUID>
    public let fingerprint: String
    public let isExecutable: Bool

    public var errors: [CompositeValidationIssue] {
        issues.filter { $0.severity == .error }
    }

    public var warnings: [CompositeValidationIssue] {
        issues.filter { $0.severity == .warning }
    }

    public var hasErrors: Bool {
        !errors.isEmpty
    }

    public var hasWarnings: Bool {
        !warnings.isEmpty
    }
}

public enum CompositeMenuItemValidator: Sendable {
    public static let maxCompositeNameLength = 80
    public static let maxStepNameLength = 80
    public static let maxCommandTemplateLength = 2_000
    public static let maxStepCount = 20

    public static func validate(_ composite: CompositeMenuItemConfig) -> CompositeValidationResult {
        var issues: [CompositeValidationIssue] = []
        var hasCompositeBlockingError = false

        if composite.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(
                issue(
                    .blankCompositeName,
                    .error,
                    "Composite menu name is required."
                )
            )
            hasCompositeBlockingError = true
        }

        if composite.name.count > maxCompositeNameLength {
            issues.append(
                issue(
                    .compositeNameTooLong,
                    .error,
                    "Composite menu name must be \(maxCompositeNameLength) characters or fewer."
                )
            )
            hasCompositeBlockingError = true
        }

        if composite.steps.isEmpty {
            issues.append(
                issue(
                    .noSteps,
                    .error,
                    "Composite menu must contain at least one step."
                )
            )
            hasCompositeBlockingError = true
        }

        if composite.steps.count > maxStepCount {
            issues.append(
                issue(
                    .tooManySteps,
                    .error,
                    "Composite menu can contain at most \(maxStepCount) steps."
                )
            )
            hasCompositeBlockingError = true
        }

        var executableStepIDs = Set<UUID>()
        for step in composite.steps {
            let stepIssues = validateStep(step)
            issues.append(contentsOf: stepIssues)

            let stepHasBlockingError = stepIssues.contains { $0.severity == .error }
            if step.isEnabled && !stepHasBlockingError {
                executableStepIDs.insert(step.id)
            }
        }

        let fingerprint = makeFingerprint(for: composite, executableStepIDs: executableStepIDs)
        return CompositeValidationResult(
            issues: issues,
            executableStepIDs: executableStepIDs,
            fingerprint: fingerprint,
            isExecutable: composite.isEnabled && !hasCompositeBlockingError && !executableStepIDs.isEmpty
        )
    }

    private static func validateStep(_ step: CompositeCommandStep) -> [CompositeValidationIssue] {
        guard step.isEnabled else {
            return []
        }

        var issues: [CompositeValidationIssue] = []
        let trimmedName = step.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTemplate = step.commandTemplate.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            issues.append(
                issue(
                    .blankStepName,
                    .error,
                    "Step name is required.",
                    stepID: step.id
                )
            )
        }

        if step.name.count > maxStepNameLength {
            issues.append(
                issue(
                    .stepNameTooLong,
                    .error,
                    "Step name must be \(maxStepNameLength) characters or fewer.",
                    stepID: step.id
                )
            )
        }

        if trimmedTemplate.isEmpty {
            issues.append(
                issue(
                    .blankCommandTemplate,
                    .error,
                    "Command template is required.",
                    stepID: step.id
                )
            )
        }

        if step.commandTemplate.count > maxCommandTemplateLength {
            issues.append(
                issue(
                    .commandTemplateTooLong,
                    .error,
                    "Command template must be \(maxCommandTemplateLength) characters or fewer.",
                    stepID: step.id
                )
            )
        }

        switch step.kind {
        case .app:
            if step.appPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                issues.append(
                    issue(
                        .appStepMissingAppPath,
                        .error,
                        "App step requires an app path.",
                        stepID: step.id
                    )
                )
            }
            if step.commandTemplate.contains("{bundle}")
                && (step.bundleId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                issues.append(
                    issue(
                        .appStepMissingBundleId,
                        .error,
                        "App step command uses {bundle}, so it requires a bundle ID.",
                        stepID: step.id
                    )
                )
            }
            if !step.commandTemplate.contains("{app}") && !step.commandTemplate.contains("{bundle}") {
                issues.append(
                    issue(
                        .appStepMissingAppPlaceholder,
                        .error,
                        "App step command must include {app} or {bundle}.",
                        stepID: step.id
                    )
                )
            }
        case .shell:
            if step.commandTemplate.contains("{app}") {
                issues.append(
                    issue(
                        .shellStepContainsAppPlaceholder,
                        .error,
                        "Shell step cannot use {app}.",
                        stepID: step.id
                    )
                )
            }
        }

        if !trimmedTemplate.isEmpty && !step.commandTemplate.contains("{path}") {
            issues.append(
                issue(
                    .missingPathPlaceholder,
                    .warning,
                    "Command does not include {path}; it will not receive the Finder selection.",
                    stepID: step.id
                )
            )
        }

        for pattern in ShellCommandSafety.dangerousPatterns(in: step.commandTemplate) {
            issues.append(
                issue(
                    .dangerousCommandPattern,
                    .warning,
                    "Command contains a potentially dangerous shell pattern.",
                    stepID: step.id,
                    pattern: pattern
                )
            )
        }

        return issues
    }

    private static func issue(
        _ code: CompositeValidationIssueCode,
        _ severity: CompositeValidationIssueSeverity,
        _ message: String,
        stepID: UUID? = nil,
        pattern: String? = nil
    ) -> CompositeValidationIssue {
        CompositeValidationIssue(
            code: code,
            severity: severity,
            message: message,
            stepID: stepID,
            pattern: pattern
        )
    }

    private static func makeFingerprint(
        for composite: CompositeMenuItemConfig,
        executableStepIDs: Set<UUID>
    ) -> String {
        var fields: [String] = [
            "composite-v3",
            composite.id.uuidString.lowercased(),
            composite.name,
            composite.iconName ?? "",
            String(composite.isEnabled),
            executableStepIDs
                .map { $0.uuidString.lowercased() }
                .sorted()
                .joined(separator: ","),
        ]

        for step in composite.steps {
            fields.append(contentsOf: [
                step.id.uuidString.lowercased(),
                step.kind.rawValue,
                step.name,
                step.commandTemplate,
                step.appPath ?? "",
                step.bundleId ?? "",
                String(step.isEnabled),
            ])
        }

        return ScriptFingerprint.make(fields: fields)
    }
}
