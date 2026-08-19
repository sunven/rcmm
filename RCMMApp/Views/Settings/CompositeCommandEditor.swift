import RCMMShared
import SwiftUI

struct CompositeCommandEditor: View {
    let config: CompositeMenuItemConfig
    let onRename: (String) -> Void
    let onAddShellStep: () -> Void
    let onAddAppStep: () -> Void
    let onReplaceAppStep: (CompositeCommandStep) -> Void
    let onUpdateStep: (CompositeCommandStep, String, String, String?, String?, Bool) -> Void
    let onDeleteStep: (UUID) -> Void
    let onMoveStep: (IndexSet, Int) -> Void

    @State private var editedName: String
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField: Hashable {
        case name
    }

    init(
        config: CompositeMenuItemConfig,
        onRename: @escaping (String) -> Void,
        onAddShellStep: @escaping () -> Void,
        onAddAppStep: @escaping () -> Void,
        onReplaceAppStep: @escaping (CompositeCommandStep) -> Void,
        onUpdateStep: @escaping (CompositeCommandStep, String, String, String?, String?, Bool) -> Void,
        onDeleteStep: @escaping (UUID) -> Void,
        onMoveStep: @escaping (IndexSet, Int) -> Void
    ) {
        self.config = config
        self.onRename = onRename
        self.onAddShellStep = onAddShellStep
        self.onAddAppStep = onAddAppStep
        self.onReplaceAppStep = onReplaceAppStep
        self.onUpdateStep = onUpdateStep
        self.onDeleteStep = onDeleteStep
        self.onMoveStep = onMoveStep
        _editedName = State(initialValue: config.name)
    }

    private var issues: [MenuEntryIssue] {
        MenuEntryEvaluator
            .evaluate(.composite(config), environment: .filesystemAware)
            .issues
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("组合命令名称", text: $editedName)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .focused($focusedField, equals: .name)
                    .onSubmit {
                        commitName()
                    }
                    .onChange(of: config.name) { _, newValue in
                        if editedName != newValue {
                            editedName = newValue
                        }
                    }

                Menu {
                    Button("应用步骤", action: onAddAppStep)
                    Button("Shell 步骤", action: onAddShellStep)
                } label: {
                    Label("添加步骤", systemImage: "plus")
                }
                .controlSize(.small)
            }

            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(issues.prefix(4)) { issue in
                        ValidationIssueRow(isError: issue.severity == .error, message: issue.message)
                    }
                }
            }

            if config.steps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("还没有步骤", systemImage: "rectangle.stack.badge.plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("添加第一个 Shell 步骤后，Finder 会按这里的顺序执行。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button {
                        onAddShellStep()
                    } label: {
                        Label("添加第一个步骤", systemImage: "plus")
                    }
                    .controlSize(.small)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(config.steps.enumerated()), id: \.element.id) { index, step in
                        CompositeStepEditorRow(
                            step: step,
                            issues: issues.filter { $0.childID == step.id },
                            canMoveUp: index > 0,
                            canMoveDown: index < config.steps.count - 1,
                            onUpdate: { name, commandTemplate, appPath, bundleId, isEnabled in
                                onUpdateStep(step, name, commandTemplate, appPath, bundleId, isEnabled)
                            },
                            onReplaceApp: step.kind == .app ? { onReplaceAppStep(step) } : nil,
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
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue != nil, oldValue != newValue {
                commitName()
            }
        }
        .onDisappear {
            commitName()
        }
    }

    private func commitName() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != config.name else { return }
        onRename(trimmed)
    }
}

private struct CompositeStepEditorRow: View {
    let step: CompositeCommandStep
    let issues: [MenuEntryIssue]
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onUpdate: (String, String, String?, String?, Bool) -> Void
    let onReplaceApp: (() -> Void)?
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    @State private var name: String
    @State private var commandTemplate: String
    @State private var appPath: String
    @State private var bundleId: String
    @State private var isEnabled: Bool
    @FocusState private var focusedField: FocusedField?

    private enum FocusedField: Hashable {
        case name
        case command
        case appPath
        case bundleId
    }

    init(
        step: CompositeCommandStep,
        issues: [MenuEntryIssue],
        canMoveUp: Bool,
        canMoveDown: Bool,
        onUpdate: @escaping (String, String, String?, String?, Bool) -> Void,
        onReplaceApp: (() -> Void)?,
        onDelete: @escaping () -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void
    ) {
        self.step = step
        self.issues = issues
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onUpdate = onUpdate
        self.onReplaceApp = onReplaceApp
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
                    .focused($focusedField, equals: .name)
                    .onSubmit(commitDraft)

                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()

                if let onReplaceApp {
                    Button(action: onReplaceApp) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.plain)
                    .help("替换应用")
                }

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
                .focused($focusedField, equals: .command)
                .onSubmit(commitDraft)

            if step.kind == .app {
                TextField("应用路径", text: $appPath)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .focused($focusedField, equals: .appPath)
                    .onSubmit(commitDraft)
                TextField("Bundle ID", text: $bundleId)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .focused($focusedField, equals: .bundleId)
                    .onSubmit(commitDraft)
            }

            if !issues.isEmpty {
                ForEach(issues) { issue in
                    ValidationIssueRow(isError: issue.severity == .error, message: issue.message)
                }
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
        .onChange(of: isEnabled) { _, _ in
            commitDraft()
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue != nil, oldValue != newValue {
                commitDraft()
            }
        }
        .onDisappear {
            commitDraft()
        }
    }

    private var hasChanges: Bool {
        name != step.name
            || commandTemplate != step.commandTemplate
            || appPath.nilIfBlank != step.appPath
            || bundleId.nilIfBlank != step.bundleId
            || isEnabled != step.isEnabled
    }

    private func commitDraft() {
        guard hasChanges else { return }
        onUpdate(
            name,
            commandTemplate,
            appPath.nilIfBlank,
            bundleId.nilIfBlank,
            isEnabled
        )
    }
}
