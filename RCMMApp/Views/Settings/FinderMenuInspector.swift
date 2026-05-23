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
                    VStack(alignment: .leading, spacing: 12) {
                        header(summary)
                        statusPanel(summary)
                        detailPanel(summary)
                        editorPanel()

                        if case .newFile(let config) = entry {
                            newFilePanel(config)
                        }
                    }
                    .padding(16)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text("选择一个菜单项")
                        .font(.callout.weight(.medium))
                    Text("选中左侧 Finder 菜单项后，这里会显示状态和详情。")
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
        HStack(alignment: .top, spacing: 10) {
            icon(for: summary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(summary.title)
                    .font(.headline)
                    .lineLimit(2)

                Text("\(summary.typeLabel) · 第 \(summary.position) 项，共 \(summary.total) 项")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(summary.title)，\(summary.typeLabel)，第 \(summary.position) 项，共 \(summary.total) 项")
    }

    private func statusPanel(_ summary: FinderMenuEntrySummary) -> some View {
        InspectorPanel(title: "状态") {
            HStack(spacing: 8) {
                FinderMenuStatusBadge(summary: summary)
                Text(summary.isEnabled ? "已启用" : "已停用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if let statusDetail = summary.statusDetail, !statusDetail.isEmpty {
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func detailPanel(_ summary: FinderMenuEntrySummary) -> some View {
        InspectorPanel(title: "详情") {
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
}

private struct InspectorPanel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
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
                .textSelection(.enabled)
        }
    }
}
