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
                    "组合命令名称不能为空。"
                )
            )
            hasCompositeBlockingError = true
        }

        if composite.name.count > maxCompositeNameLength {
            issues.append(
                issue(
                    .compositeNameTooLong,
                    .error,
                    "组合命令名称不能超过 \(maxCompositeNameLength) 个字符。"
                )
            )
            hasCompositeBlockingError = true
        }

        if composite.steps.isEmpty {
            issues.append(
                issue(
                    .noSteps,
                    .error,
                    "组合命令至少需要一个步骤。"
                )
            )
            hasCompositeBlockingError = true
        }

        if composite.steps.count > maxStepCount {
            issues.append(
                issue(
                    .tooManySteps,
                    .error,
                    "组合命令最多只能有 \(maxStepCount) 个步骤。"
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
                    "步骤名称不能为空。",
                    childID: step.id
                )
            )
        }

        if step.name.count > maxStepNameLength {
            issues.append(
                issue(
                    .stepNameTooLong,
                    .error,
                    "步骤名称不能超过 \(maxStepNameLength) 个字符。",
                    childID: step.id
                )
            )
        }

        if trimmedTemplate.isEmpty {
            issues.append(
                issue(
                    .blankCommandTemplate,
                    .error,
                    "命令模板不能为空。",
                    childID: step.id
                )
            )
        }

        if step.commandTemplate.count > maxCommandTemplateLength {
            issues.append(
                issue(
                    .commandTemplateTooLong,
                    .error,
                    "命令模板不能超过 \(maxCommandTemplateLength) 个字符。",
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
                        "应用步骤需要应用路径。",
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
                        "命令里用了 {bundle}，因此需要填写 Bundle ID。",
                        childID: step.id
                    )
                )
            }
            if !step.commandTemplate.contains("{app}") && !step.commandTemplate.contains("{bundle}") {
                issues.append(
                    issue(
                        .appStepMissingAppPlaceholder,
                        .error,
                        "应用步骤的命令必须包含 {app} 或 {bundle}。",
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
                        "Shell 步骤不能使用 {app}。",
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
                    "命令未包含 {path}，不会收到 Finder 选中的目标。",
                    childID: step.id
                )
            )
        }

        for pattern in ShellCommandSafety.dangerousPatterns(in: step.commandTemplate) {
            issues.append(
                issue(
                    .dangerousCommandPattern,
                    .warning,
                    "命令包含潜在危险的 shell 片段。",
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
