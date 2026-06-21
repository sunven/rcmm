import RCMMShared
import SwiftUI

struct CompositeCommandEditor: View {
    let config: CompositeMenuItemConfig
    let onRename: (String) -> Void
    let onAddShellStep: () -> Void
    let onUpdateStep: (CompositeCommandStep, String, String, String?, String?, Bool) -> Void
    let onDeleteStep: (UUID) -> Void
    let onMoveStep: (IndexSet, Int) -> Void

    @State private var editedName: String

    init(
        config: CompositeMenuItemConfig,
        onRename: @escaping (String) -> Void,
        onAddShellStep: @escaping () -> Void,
        onUpdateStep: @escaping (CompositeCommandStep, String, String, String?, String?, Bool) -> Void,
        onDeleteStep: @escaping (UUID) -> Void,
        onMoveStep: @escaping (IndexSet, Int) -> Void
    ) {
        self.config = config
        self.onRename = onRename
        self.onAddShellStep = onAddShellStep
        self.onUpdateStep = onUpdateStep
        self.onDeleteStep = onDeleteStep
        self.onMoveStep = onMoveStep
        _editedName = State(initialValue: config.name)
    }

    private var validation: CompositeValidationResult {
        CompositeMenuItemValidator.validate(config)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("组合命令名称", text: $editedName)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .onSubmit {
                        commitName()
                    }
                    .onChange(of: config.name) { _, newValue in
                        if editedName != newValue {
                            editedName = newValue
                        }
                    }

                Button("保存名称") {
                    commitName()
                }
                .controlSize(.small)
                .disabled(editedName == config.name)

                Button {
                    onAddShellStep()
                } label: {
                    Label("添加步骤", systemImage: "plus")
                }
                .controlSize(.small)
            }

            if !validation.issues.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(validation.issues.prefix(4)) { issue in
                        ValidationIssueRow(isError: issue.severity == .error, message: issue.message)
                    }
                }
            }

            if config.steps.isEmpty {
                Text("暂无步骤")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(config.steps.enumerated()), id: \.element.id) { index, step in
                        CompositeStepEditorRow(
                            step: step,
                            issues: validation.issues.filter { $0.stepID == step.id },
                            canMoveUp: index > 0,
                            canMoveDown: index < config.steps.count - 1,
                            onUpdate: { name, commandTemplate, appPath, bundleId, isEnabled in
                                onUpdateStep(step, name, commandTemplate, appPath, bundleId, isEnabled)
                            },
                            onDelete: {
                                onDeleteStep(step.id)
                            },
                            onMoveUp: {
                                onMoveStep(IndexSet(integer: index), index - 1)
                            },
                            onMoveDown: {
                                onMoveStep(IndexSet(integer: index), index + 2)
                            }
                        )
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func commitName() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != config.name else { return }
        onRename(trimmed)
    }
}

private struct CompositeStepEditorRow: View {
    let step: CompositeCommandStep
    let issues: [CompositeValidationIssue]
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onUpdate: (String, String, String?, String?, Bool) -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    @State private var name: String
    @State private var commandTemplate: String
    @State private var appPath: String
    @State private var bundleId: String
    @State private var isEnabled: Bool

    init(
        step: CompositeCommandStep,
        issues: [CompositeValidationIssue],
        canMoveUp: Bool,
        canMoveDown: Bool,
        onUpdate: @escaping (String, String, String?, String?, Bool) -> Void,
        onDelete: @escaping () -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void
    ) {
        self.step = step
        self.issues = issues
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        _name = State(initialValue: step.name)
        _commandTemplate = State(initialValue: step.commandTemplate)
        _appPath = State(initialValue: step.appPath ?? "")
        _bundleId = State(initialValue: step.bundleId ?? "")
        _isEnabled = State(initialValue: step.isEnabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(step.kind == .app ? "App" : "Shell")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(step.kind == .app ? .blue : .purple)
                    .frame(width: 40, alignment: .leading)

                TextField("步骤名称", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)

                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()

                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.plain)
                .disabled(!canMoveUp)
                .help("上移")

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.plain)
                .disabled(!canMoveDown)
                .help("下移")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("删除步骤")
            }

            TextField("命令模板", text: $commandTemplate)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)

            if step.kind == .app {
                TextField("应用路径", text: $appPath)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                TextField("Bundle ID", text: $bundleId)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }

            if !issues.isEmpty {
                ForEach(issues) { issue in
                    ValidationIssueRow(isError: issue.severity == .error, message: issue.message)
                }
            }

            HStack {
                Spacer()
                Button("保存步骤") {
                    onUpdate(
                        name,
                        commandTemplate,
                        appPath.nilIfBlank,
                        bundleId.nilIfBlank,
                        isEnabled
                    )
                }
                .controlSize(.small)
                .disabled(!hasChanges)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.04))
        )
        .onChange(of: step) { _, newValue in
            name = newValue.name
            commandTemplate = newValue.commandTemplate
            appPath = newValue.appPath ?? ""
            bundleId = newValue.bundleId ?? ""
            isEnabled = newValue.isEnabled
        }
    }

    private var hasChanges: Bool {
        name != step.name
            || commandTemplate != step.commandTemplate
            || appPath.nilIfBlank != step.appPath
            || bundleId.nilIfBlank != step.bundleId
            || isEnabled != step.isEnabled
    }
}
