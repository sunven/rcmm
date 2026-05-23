import RCMMShared
import SwiftUI

struct NewFileSettingsTab: View {
    @Environment(AppState.self) private var appState

    private enum Layout {
        static let contentPadding = EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let config = appState.primaryNewFileMenu {
                header(for: config)

                Divider()

                ScrollView {
                    NewFileMenuEditor(
                        config: config,
                        onRename: { name in
                            appState.updateNewFileMenuName(for: config.id, name: name)
                        },
                        onAddTemplate: {
                            appState.addNewFileTemplate(to: config.id)
                        },
                        onUpdateTemplate: { template, displayName, baseName, fileExtension, creationMode, templatePath, initialContent, isEnabled in
                            appState.updateNewFileTemplate(
                                menuID: config.id,
                                templateID: template.id,
                                displayName: displayName,
                                baseName: baseName,
                                fileExtension: fileExtension,
                                creationMode: creationMode,
                                templatePath: templatePath,
                                initialContent: initialContent,
                                isEnabled: isEnabled
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
                    .padding(Layout.contentPadding)
                }
            } else {
                emptyState
            }
        }
    }

    private func header(for config: NewFileMenuConfig) -> some View {
        let status = NewFileMenuStatusResolver.resolve(
            config: config,
            publishStates: appState.scriptPublishStates
        )

        return HStack(spacing: 10) {
            Image(systemName: config.iconName ?? "document.badge.plus")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 17, height: 17)
                .foregroundStyle(config.isEnabled ? .primary : .secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.callout)
                    .foregroundStyle(config.isEnabled ? .primary : .secondary)
                    .lineLimit(1)

                Text("\(config.templates.count) 个模板")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            statusBadge(status)

            Toggle("", isOn: Binding(
                get: { config.isEnabled },
                set: { appState.toggleEntry(for: config.id.uuidString, isEnabled: $0) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
            .help(config.isEnabled ? "停用新建文件菜单" : "启用新建文件菜单")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func statusBadge(_ status: NewFileMenuStatus) -> some View {
        Text(status.displayName)
            .font(.caption2.weight(.medium))
            .foregroundStyle(statusColor(for: status))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(statusColor(for: status).opacity(0.12))
            )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("未找到新建文件菜单")
                .foregroundStyle(.secondary)

            Button("恢复新建文件菜单") {
                appState.ensureNewFileMenu()
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusColor(for status: NewFileMenuStatus) -> Color {
        switch status.kind {
        case .disabled, .partiallyAvailable:
            return .orange
        case .unavailable:
            return .red
        case .warning:
            return .yellow
        case .syncing, .ready:
            return .secondary
        }
    }
}
