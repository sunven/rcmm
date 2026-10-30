import AppKit
import RCMMShared
import SwiftUI

struct FinderMenuInspector: View {
    @Environment(SettingsDraftStore.self) private var drafts
    let summary: FinderMenuEntrySummary?
    let entry: MenuEntry?
    var onOpenNewFileSettings: () -> Void
    var onOpenCompositeSettings: () -> Void = {}

    var body: some View {
        Group {
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
                placeholder
            }
        }
        .frame(minWidth: 300, maxWidth: 330, maxHeight: .infinity)
        .background(RCMMColor.window)
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(RCMMColor.textFaint)
                .symbolRenderingMode(.hierarchical)

            Text("选择一个菜单项")
                .font(RCMMFont.emptyTitle)
                .foregroundStyle(RCMMColor.textPrimary)

            Text("状态、路径、脚本同步和编辑器会显示在这里。")
                .font(RCMMFont.secondary)
                .foregroundStyle(RCMMColor.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func header(_ summary: FinderMenuEntrySummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                icon(for: summary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(RCMMColor.textPrimary)
                        .lineLimit(2)

                    Text("\(summary.typeLabel) · 第 \(summary.position) 项，共 \(summary.total) 项")
                        .font(RCMMFont.caption)
                        .foregroundStyle(RCMMColor.textMuted)
                }

                Spacer(minLength: 0)
            }

            FinderMenuStatusBadge(summary: summary)
        }
        .padding(.bottom, 2)
    }

    private func statusPanel(_ summary: FinderMenuEntrySummary) -> some View {
        RCMMPanel(title: "状态") {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: FinderMenuStatusStyle.symbol(for: summary.statusKind))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(FinderMenuStatusStyle.color(for: summary.statusKind))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle(for: summary))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RCMMColor.textPrimary)

                    Text(statusExplanation(for: summary))
                        .font(RCMMFont.secondary)
                        .foregroundStyle(RCMMColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    if let nextStep = nextStep(for: summary) {
                        Text("下一步：\(nextStep)")
                            .font(RCMMFont.caption)
                            .foregroundStyle(RCMMColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if summary.statusKind != .ready,
               let statusDetail = summary.statusDetail,
               !statusDetail.isEmpty {
                RCMMCodeBlock(text: statusDetail)
            }
        }
    }

    private func detailPanel(_ summary: FinderMenuEntrySummary) -> some View {
        RCMMPanel(title: "详情") {
            RCMMInfoRow(label: "类型", value: summary.typeLabel)
            RCMMInfoRow(label: "位置", value: "\(summary.position) / \(summary.total)")

            switch entry {
            case .custom(let config):
                if config.executionMode == .currentDirectory {
                    RCMMInfoRow(label: "执行方式", value: config.executionMode.displayName)
                    RCMMInfoRow(label: "命令", value: config.customCommand ?? "未设置", monospaced: true)
                } else {
                    RCMMInfoRow(label: "应用路径", value: config.appPath, monospaced: true)
                    if let bundleId = config.bundleId {
                        RCMMInfoRow(label: "Bundle ID", value: bundleId, monospaced: true)
                    }
                }
            case .composite(let config):
                RCMMInfoRow(label: "步骤", value: "\(config.steps.count)")
                ForEach(Array(config.steps.prefix(4).enumerated()), id: \.element.id) { index, step in
                    RCMMInfoRow(label: "\(index + 1)", value: step.name)
                }
                if config.steps.count > 4 {
                    Text("另有 \(config.steps.count - 4) 个步骤")
                        .font(RCMMFont.caption)
                        .foregroundStyle(RCMMColor.textMuted)
                }
            case .newFile(let config):
                RCMMInfoRow(label: "模板", value: "\(config.templates.count)")
            case .builtIn, .none:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func editorPanel() -> some View {
        switch entry {
        case .custom(let config):
            RCMMPanel(title: config.executionMode == .currentDirectory ? "命令编辑" : "应用命令") {
                CommandEditor(
                    config: Binding(
                        get: { drafts.command(for: config) },
                        set: { drafts.updateCommand($0) }
                    ),
                    defaultCommand: resolveDefaultCommand(for: config)
                )
                .id(config.id)
            }
        case .composite:
            RCMMPanel(title: "组合命令") {
                Text("组合命令在独立设置页中创建和编辑。")
                    .font(RCMMFont.secondary)
                    .foregroundStyle(RCMMColor.textMuted)

                Button {
                    onOpenCompositeSettings()
                } label: {
                    Label("打开组合命令设置", systemImage: "arrow.right")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        case .builtIn, .newFile, .none:
            EmptyView()
        }
    }

    private func newFilePanel(_ config: NewFileMenuConfig) -> some View {
        RCMMPanel(title: "新建文件") {
            ForEach(config.templates.prefix(3)) { template in
                HStack(spacing: 8) {
                    Text(template.displayName)
                        .font(RCMMFont.secondary)
                        .foregroundStyle(RCMMColor.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(".\(template.fileExtension)")
                        .font(RCMMFont.code)
                        .foregroundStyle(RCMMColor.textMuted)
                }
            }

            Button {
                onOpenNewFileSettings()
            } label: {
                Label("打开新建文件设置", systemImage: "arrow.right")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func icon(for summary: FinderMenuEntrySummary) -> some View {
        if let appPath = summary.appPath {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appPath))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
        } else if let symbolName = summary.symbolName {
            Image(systemName: symbolName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(RCMMColor.textMuted)
                .frame(width: 30, height: 30)
        } else {
            Image(systemName: "app")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(RCMMColor.textMuted)
                .frame(width: 30, height: 30)
        }
    }

    private func statusTitle(for summary: FinderMenuEntrySummary) -> String {
        switch summary.statusKind {
        case .ready:
            return "已启用并已发布"
        case .syncing:
            return "正在同步"
        case .failed:
            return "同步失败"
        case .unavailable:
            return "当前不可用"
        case .partiallyAvailable:
            return "部分可用"
        case .warning:
            return "可用，但有警告"
        case .disabled:
            return "已停用"
        case .system:
            return "内置系统菜单项"
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
        case .system:
            return "这是 rcmm 内置的系统菜单项。"
        }
    }

    private func nextStep(for summary: FinderMenuEntrySummary) -> String? {
        switch summary.statusKind {
        case .ready, .system:
            return nil
        case .syncing:
            return "等待同步完成，完成后状态会变为就绪。"
        case .failed, .unavailable, .partiallyAvailable, .warning:
            return "修复下方配置后保存。"
        case .disabled:
            return "打开开关后才会显示在 Finder 中。"
        }
    }
}
