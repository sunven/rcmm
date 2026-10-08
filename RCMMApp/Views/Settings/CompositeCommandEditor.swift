import RCMMShared
import SwiftUI

struct CompositeCommandEditor: View {
    @Environment(SettingsDraftStore.self) private var drafts
    @Binding var config: CompositeMenuItemConfig
    let onAddShellStep: () -> Void
    let onAddAppStep: () -> Void
    let onReplaceAppStep: (CompositeCommandStep) -> Void
    let onUpdateStep: (CompositeCommandStep, String, String, String?, String?, Bool) -> Void
    let onDeleteStep: (UUID) -> Void
    let onMoveStep: (IndexSet, Int) -> Void

    private var issues: [MenuEntryIssue] {
        drafts.issues(for: .composite(config.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("组合命令名称", text: $config.name)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)

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
                            step: Binding(
                                get: { config.steps.first { $0.id == step.id } ?? step },
                                set: { value in
                                    onUpdateStep(step, value.name, value.commandTemplate, value.appPath, value.bundleId, value.isEnabled)
                                }
                            ),
                            issues: issues.filter { $0.childID == step.id },
                            canMoveUp: index > 0,
                            canMoveDown: index < config.steps.count - 1,
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
    }
}

private struct CompositeStepEditorRow: View {
    @Binding var step: CompositeCommandStep
    let issues: [MenuEntryIssue]
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onReplaceApp: (() -> Void)?
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(step.kind == .app ? "App" : "Shell")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(step.kind == .app ? .blue : .purple)
                    .frame(width: 40, alignment: .leading)

                TextField("步骤名称", text: $step.name)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)

                Toggle("", isOn: $step.isEnabled)
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

            TextField("命令模板", text: $step.commandTemplate)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)

            if step.kind == .app {
                TextField("应用路径", text: Binding(get: { step.appPath ?? "" }, set: { step.appPath = $0.isEmpty ? nil : $0 }))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                TextField("Bundle ID", text: Binding(get: { step.bundleId ?? "" }, set: { step.bundleId = $0.isEmpty ? nil : $0 }))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
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
    }
}
