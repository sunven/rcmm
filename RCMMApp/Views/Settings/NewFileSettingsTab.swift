import RCMMShared
import SwiftUI

struct NewFileSettingsTab: View {
    @Environment(AppState.self) private var appState

    private enum Layout {
        static let contentPadding = EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let config = appState.primaryNewFileMenu {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        pageHeader(for: config)

                        NewFileMenuEditor(
                            config: config,
                            onUpdateTemplate: { template in
                                appState.updateNewFileTemplate(
                                    menuID: config.id,
                                    templateID: template.id,
                                    displayName: template.displayName,
                                    baseName: template.baseName,
                                    fileExtension: template.fileExtension,
                                    creationMode: template.creationMode,
                                    templatePath: template.templatePath,
                                    initialContent: template.initialContent,
                                    isEnabled: template.isEnabled
                                )
                            },
                            onDeleteTemplate: { templateID in
                                appState.removeNewFileTemplate(
                                    menuID: config.id,
                                    templateID: templateID
                                )
                            },
                            onMoveTemplate: { source, destination in
                                appState.moveNewFileTemplate(
                                    menuID: config.id,
                                    from: source,
                                    to: destination
                                )
                            }
                        )

                        usageTip
                    }
                    .padding(Layout.contentPadding)
                }
            } else {
                emptyState
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func pageHeader(for config: NewFileMenuConfig) -> some View {
        let status = NewFileMenuStatusResolver.resolve(
            config: config,
            publishStates: appState.scriptPublishStates
        )

        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("新建文件")
                    .font(.title3.weight(.bold))
                Text("自定义快速新建文件模板，提升工作效率")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 14) {
                HStack(spacing: 8) {
                    Text("\(config.templates.count) 个模板")
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )

                    headerStatusBadge(status)

                    Toggle(
                        config.isEnabled ? "已启用" : "已停用",
                        isOn: Binding(
                            get: { config.isEnabled },
                            set: { appState.toggleEntry(for: config.id.uuidString, isEnabled: $0) }
                        )
                    )
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(config.isEnabled ? Color.accentColor : .secondary)
                    .padding(.leading, 10)
                    .padding(.trailing, 6)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(config.isEnabled ? 0.10 : 0.04))
                    )
                    .help(config.isEnabled ? "停用新建文件菜单" : "启用新建文件菜单")
                }

                Button {
                    appState.addNewFileTemplate(to: config.id)
                } label: {
                    Label("添加模板", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .help("添加新模板")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headerStatusBadge(_ status: NewFileMenuStatus) -> some View {
        Label(status.displayName, systemImage: statusSymbol(for: status))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusColor(for: status))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(statusColor(for: status).opacity(0.11))
            )
            .accessibilityLabel("状态：\(status.displayName)")
    }

    private var usageTip: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lightbulb")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color(nsColor: .textBackgroundColor).opacity(0.82)))

            VStack(alignment: .leading, spacing: 2) {
                Text("使用提示")
                    .font(.caption.weight(.semibold))
                Text("添加模板后，可在 Finder 右键菜单中快速新建文件。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.07))
        )
    }

    private func statusSymbol(for status: NewFileMenuStatus) -> String {
        switch status.kind {
        case .disabled:
            return "pause.circle.fill"
        case .unavailable:
            return "exclamationmark.triangle.fill"
        case .partiallyAvailable, .warning:
            return "exclamationmark.circle.fill"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .ready:
            return "checkmark.circle.fill"
        }
    }

    private func statusColor(for status: NewFileMenuStatus) -> Color {
        switch status.kind {
        case .disabled, .partiallyAvailable, .warning:
            return NewFileSettingsColor.warning
        case .unavailable:
            return NewFileSettingsColor.error
        case .syncing:
            return NewFileSettingsColor.info
        case .ready:
            return NewFileSettingsColor.success
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "document.badge.plus")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            Text("新建文件菜单尚未恢复")
                .font(.callout.weight(.semibold))

            Text("恢复后可以配置模板，并让 Finder 右键菜单创建常用文件。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                appState.ensureNewFileMenu()
            } label: {
                Label("恢复新建文件菜单", systemImage: "arrow.clockwise")
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .controlSize(.small)
        }
        .padding(24)
        .frame(maxWidth: 340)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}
