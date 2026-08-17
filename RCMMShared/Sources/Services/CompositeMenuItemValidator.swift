import Foundation

struct CompositeValidationResult: Hashable, Sendable {
    let issues: [MenuEntryIssue]
    let executableStepIDs: Set<UUID>
    let fingerprint: String
    let isExecutable: Bool

    var errors: [MenuEntryIssue] { issues.errors }
    var warnings: [MenuEntryIssue] { issues.warnings }
    var hasErrors: Bool { issues.hasErrors }
    var hasWarnings: Bool { issues.hasWarnings }
}

/// composite 项的规则。`MenuEntryEvaluator` 的实现，调用方走 evaluator。
///
/// `executableStepIDs` 是「哪些步骤会被写进那**一个**脚本」，与 New File Menu 的
/// `executableTemplateIDs`（哪些子项**本身就是**脚本）语义不同，因此没有合并到一个字段里。
enum CompositeMenuItemValidator: Sendable {
    static let maxCompositeNameLength = 80
    static let maxStepNameLength = 80
    static let maxCommandTemplateLength = 2_000
    static let maxStepCount = 20

    static func validate(_ composite: CompositeMenuItemConfig) -> CompositeValidationResult {
        var issues: [MenuEntryIssue] = []
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

            let stepHasBlockingError = stepIssues.hasErrors
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

    private static func validateStep(_ step: CompositeCommandStep) -> [MenuEntryIssue] {
        guard step.isEnabled else {
            return []
        }

        var issues: [MenuEntryIssue] = []
        let trimmedName = step.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTemplate = step.commandTemplate.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            issues.append(
                issue(
                    .blankStepName,
                    .error,
                    "Step name is required.",
                    childID: step.id
                )
            )
        }

        if step.name.count > maxStepNameLength {
            issues.append(
                issue(
                    .stepNameTooLong,
                    .error,
                    "Step name must be \(maxStepNameLength) characters or fewer.",
                    childID: step.id
                )
            )
        }

        if trimmedTemplate.isEmpty {
            issues.append(
                issue(
                    .blankCommandTemplate,
                    .error,
                    "Command template is required.",
                    childID: step.id
                )
            )
        }

        if step.commandTemplate.count > maxCommandTemplateLength {
            issues.append(
                issue(
                    .commandTemplateTooLong,
                    .error,
                    "Command template must be \(maxCommandTemplateLength) characters or fewer.",
                    childID: step.id
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
                        childID: step.id
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
                        childID: step.id
                    )
                )
            }
            if !step.commandTemplate.contains("{app}") && !step.commandTemplate.contains("{bundle}") {
                issues.append(
                    issue(
                        .appStepMissingAppPlaceholder,
                        .error,
                        "App step command must include {app} or {bundle}.",
                        childID: step.id
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
                        childID: step.id
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
                    childID: step.id
                )
            )
        }

        for pattern in ShellCommandSafety.dangerousPatterns(in: step.commandTemplate) {
            issues.append(
                issue(
                    .dangerousCommandPattern,
                    .warning,
                    "Command contains a potentially dangerous shell pattern.",
                    childID: step.id,
                    detail: pattern
                )
            )
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
