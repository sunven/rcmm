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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 8) {
                RCMMField("名称") {
                    TextField("组合命令名称", text: $config.name)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                }

                Menu {
                    Button("应用步骤", action: onAddAppStep)
                    Button("Shell 步骤", action: onAddShellStep)
                } label: {
                    Label("添加步骤", systemImage: "plus")
                }
                .menuStyle(.button)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(issues.prefix(4)) { issue in
                        ValidationIssueRow(isError: issue.severity == .error, message: issue.message)
                    }
                }
            }

            if config.steps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("还没有步骤")
                        .font(RCMMFont.caption.weight(.semibold))
                        .foregroundStyle(RCMMColor.textSecondary)

                    Text("添加第一个步骤后，Finder 会按这里的顺序执行。")
                        .font(RCMMFont.caption)
                        .foregroundStyle(RCMMColor.textMuted)

                    Button {
                        onAddShellStep()
                    } label: {
                        Label("添加第一个步骤", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(RCMMColor.surfaceSoft)
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
        .padding(.vertical, 4)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: step.kind == .app ? "app" : "terminal")
                        .font(.system(size: 10, weight: .medium))
                    Text(step.kind == .app ? "应用" : "Shell")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(RCMMColor.textMuted)
                .frame(width: 46, alignment: .leading)

                TextField("步骤名称", text: $step.name)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)

                Toggle("", isOn: $step.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .accessibilityLabel(step.isEnabled ? "停用步骤 \(step.name)" : "启用步骤 \(step.name)")

                stepsMenu
            }

            RCMMField("命令模板") {
                TextField("命令模板", text: $step.commandTemplate)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .font(.system(.caption, design: .monospaced))
            }

            if step.kind == .app {
                RCMMField("应用路径") {
                    TextField("应用路径", text: Binding(get: { step.appPath ?? "" }, set: { step.appPath = $0.isEmpty ? nil : $0 }))
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .font(.system(.caption, design: .monospaced))
                }

                RCMMField("Bundle ID") {
                    TextField("Bundle ID", text: Binding(get: { step.bundleId ?? "" }, set: { step.bundleId = $0.isEmpty ? nil : $0 }))
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .font(.system(.caption, design: .monospaced))
                }
            }

            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(issues) { issue in
                        ValidationIssueRow(isError: issue.severity == .error, message: issue.message)
                    }
                }
            }
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(RCMMColor.surfaceSoft)
        )
    }

    private var stepsMenu: some View {
        Menu {
            if let onReplaceApp {
                Button(action: onReplaceApp) {
                    Label("替换应用", systemImage: "arrow.triangle.2.circlepath")
                }
                Divider()
            }

            Button(action: onMoveUp) {
                Label("上移", systemImage: "arrow.up")
            }
            .disabled(!canMoveUp)

            Button(action: onMoveDown) {
                Label("下移", systemImage: "arrow.down")
            }
            .disabled(!canMoveDown)

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("删除步骤", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RCMMColor.textMuted)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("步骤操作")
    }
}
