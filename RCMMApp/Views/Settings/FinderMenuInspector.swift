import AppKit
import RCMMShared
import SwiftUI

struct FinderMenuInspector: View {
    let summary: FinderMenuEntrySummary?
    let entry: MenuEntry?
    var onOpenNewFileSettings: () -> Void
    var onUpdateCustomCommand: (MenuItemConfig, String, String?, CustomCommandExecutionMode) -> Void
    var onRenameComposite: (CompositeMenuItemConfig, String) -> Void
    var onAddCompositeShellStep: (CompositeMenuItemConfig) -> Void
    var onUpdateCompositeStep: (CompositeMenuItemConfig, CompositeCommandStep, String, String, String?, String?, Bool) -> Void
    var onDeleteCompositeStep: (CompositeMenuItemConfig, UUID) -> Void
    var onMoveCompositeStep: (CompositeMenuItemConfig, IndexSet, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let summary {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header(summary)
                        statusPanel(summary)
                        detailPanel(summary)
                        editorPanel()

                        if case .newFile(let config) = entry {
                            newFilePanel(config)
                        }
                    }
                    .padding(14)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                    Text("选择一个菜单项")
                        .font(.callout.weight(.semibold))
                    Text("状态、路径、脚本同步和编辑器会显示在这里。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
            }
        }
        .frame(minWidth: 300, maxWidth: 340, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func header(_ summary: FinderMenuEntrySummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                icon(for: summary)
                    .frame(width: 24, height: 24)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.045))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.06))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(2)

                    Text("\(summary.typeLabel) · 第 \(summary.position) 项，共 \(summary.total) 项")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            FinderMenuStatusBadge(summary: summary)
        }
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(summary.title)，\(summary.typeLabel)，第 \(summary.position) 项，共 \(summary.total) 项，\(summary.statusText)")
    }

    private func statusPanel(_ summary: FinderMenuEntrySummary) -> some View {
        InspectorPanel(title: "状态") {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: statusSymbol(for: summary))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(statusColor(for: summary))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.isEnabled ? "菜单项已启用" : "菜单项已停用")
                        .font(.caption.weight(.semibold))
                    Text(statusExplanation(for: summary))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("下一步：\(nextStep(for: summary))")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let statusDetail = summary.statusDetail, !statusDetail.isEmpty {
                Text(statusDetail)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
    }

    private func detailPanel(_ summary: FinderMenuEntrySummary) -> some View {
        InspectorPanel(title: "详情") {
            DetailRow(label: "类型", value: summary.typeLabel)
            DetailRow(label: "位置", value: "\(summary.position) / \(summary.total)")

            if let subtitle = summary.subtitle, !subtitle.isEmpty {
                DetailRow(label: "说明", value: subtitle)
            }

            switch entry {
            case .custom(let config):
                if config.executionMode == .currentDirectory {
                    DetailRow(label: "执行方式", value: config.executionMode.displayName)
                    DetailRow(label: "命令", value: config.customCommand ?? "未设置")
                } else {
                    DetailRow(label: "应用路径", value: config.appPath)
                    if let bundleId = config.bundleId {
                        DetailRow(label: "Bundle ID", value: bundleId)
                    }
                }
            case .composite(let config):
                DetailRow(label: "步骤", value: "\(config.steps.count)")
                ForEach(Array(config.steps.prefix(4).enumerated()), id: \.element.id) { index, step in
                    DetailRow(label: "\(index + 1)", value: step.name)
                }
            case .newFile(let config):
                DetailRow(label: "模板", value: "\(config.templates.count)")
            case .builtIn, .none:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func editorPanel() -> some View {
        switch entry {
        case .custom(let config):
            InspectorPanel(title: config.executionMode == .currentDirectory ? "命令编辑" : "应用命令") {
                CommandEditor(
                    name: config.appName,
                    editedCommand: config.customCommand ?? "",
                    executionMode: config.executionMode,
                    defaultCommand: resolveDefaultCommand(for: config),
                    appPath: config.appPath,
                    onSave: { name, command, executionMode in
                        onUpdateCustomCommand(config, name, command, executionMode)
                    }
                )
                .id(config.id)
            }
        case .composite(let config):
            InspectorPanel(title: "组合命令编辑") {
                CompositeCommandEditor(
                    config: config,
                    onRename: { name in
                        onRenameComposite(config, name)
                    },
                    onAddShellStep: {
                        onAddCompositeShellStep(config)
                    },
                    onUpdateStep: { step, name, commandTemplate, appPath, bundleId, isEnabled in
                        onUpdateCompositeStep(
                            config,
                            step,
                            name,
                            commandTemplate,
                            appPath,
                            bundleId,
                            isEnabled
                        )
                    },
                    onDeleteStep: { stepID in
                        onDeleteCompositeStep(config, stepID)
                    },
                    onMoveStep: { source, destination in
                        onMoveCompositeStep(config, source, destination)
                    }
                )
                .id(config.id)
            }
        case .builtIn, .newFile, .none:
            EmptyView()
        }
    }

    private func newFilePanel(_ config: NewFileMenuConfig) -> some View {
        InspectorPanel(title: "新建文件") {
            ForEach(config.templates.prefix(3)) { template in
                DetailRow(label: template.displayName, value: ".\(template.fileExtension)")
            }

            Button {
                onOpenNewFileSettings()
            } label: {
                Label("打开新建文件设置", systemImage: "arrow.right")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("打开新建文件设置")
        }
    }

    @ViewBuilder
    private func icon(for summary: FinderMenuEntrySummary) -> some View {
        if let appPath = summary.appPath {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appPath))
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let symbolName = summary.symbolName {
            Image(systemName: symbolName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.secondary)
                .padding(4)
        } else {
            Image(systemName: "app")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.secondary)
                .padding(4)
        }
    }

    private func resolveDefaultCommand(for item: MenuItemConfig) -> String {
        if item.executionMode == .currentDirectory {
            return "git pull"
        }
        if let builtIn = CommandMappingService.command(for: item.bundleId) {
            return builtIn
        }
        return "open -a \"\(item.appPath)\" {path}"
    }

    private func statusExplanation(for summary: FinderMenuEntrySummary) -> String {
        switch summary.statusKind {
        case .ready:
            return "配置已发布，Finder 右键菜单可以正常使用。"
        case .syncing:
            return "配置正在等待脚本同步，稍后会自动更新。"
        case .failed:
            return "脚本同步失败，需要检查命令或模板配置。"
        case .unavailable:
            return "当前配置缺少可执行目标，Finder 中不会正常工作。"
        case .partiallyAvailable:
            return "部分步骤可用，但仍有阻塞问题需要处理。"
        case .warning:
            return "配置可用，但存在建议修复的警告。"
        case .disabled:
            return "用户已停用此项，Finder 菜单不会显示它。"
        case .command:
            return "这是直接在 Finder 当前目录执行的命令项。"
        case .system:
            return "这是 rcmm 内置的系统菜单项。"
        }
    }

    private func nextStep(for summary: FinderMenuEntrySummary) -> String {
        switch summary.statusKind {
        case .ready, .command, .system:
            return "可在 Finder 右键菜单中使用。"
        case .syncing:
            return "等待同步完成，完成后状态会变为就绪。"
        case .failed, .unavailable, .partiallyAvailable, .warning:
            return "修复下方配置后保存。"
        case .disabled:
            return "打开开关后才会显示在 Finder 中。"
        }
    }

    private func statusSymbol(for summary: FinderMenuEntrySummary) -> String {
        switch summary.statusKind {
        case .ready:
            return "checkmark.circle.fill"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .failed, .unavailable:
            return "exclamationmark.triangle.fill"
        case .partiallyAvailable, .warning:
            return "exclamationmark.circle.fill"
        case .disabled:
            return "pause.circle.fill"
        case .command:
            return "terminal.fill"
        case .system:
            return "gearshape.fill"
        }
    }

    private func statusColor(for summary: FinderMenuEntrySummary) -> Color {
        switch summary.statusKind {
        case .failed, .unavailable:
            return .red
        case .partiallyAvailable, .warning:
            return .orange
        case .syncing, .command:
            return .blue
        case .ready:
            return .green
        case .disabled, .system:
            return .secondary
        }
    }
}

private struct InspectorPanel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.06))
            )
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "未设置" : value)
                .font(value.count > 32 ? .caption.monospaced() : .caption)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}
