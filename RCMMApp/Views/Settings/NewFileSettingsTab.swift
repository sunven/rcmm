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
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func header(for config: NewFileMenuConfig) -> some View {
        let status = NewFileMenuStatusResolver.resolve(
            config: config,
            publishStates: appState.scriptPublishStates
        )

        return HStack(spacing: 12) {
            FinderMenuRowIcon(isEnabled: config.isEnabled, isUnavailable: status.kind == .unavailable) {
                Image(systemName: config.iconName ?? "document.badge.plus")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(config.isEnabled ? .primary : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("新建文件")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(config.isEnabled ? .primary : .secondary)
                    .lineLimit(1)

                Text("\(config.name) · \(config.templates.count) 个模板")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                Text("\(config.templates.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                Text("模板")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.055))
            )

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
        .padding(.vertical, 12)
    }

    private func statusBadge(_ status: NewFileMenuStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: statusSymbol(for: status))
                .font(.system(size: 9, weight: .bold))
            Text(status.displayName)
                .font(.caption2.weight(.semibold))
        }
            .foregroundStyle(statusColor(for: status))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(statusColor(for: status).opacity(0.12))
            )
            .accessibilityLabel("状态：\(status.displayName)")
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
        case .disabled, .partiallyAvailable:
            return .orange
        case .unavailable:
            return .red
        case .warning:
            return .orange
        case .syncing:
            return .blue
        case .ready:
            return .green
        }
    }
}
