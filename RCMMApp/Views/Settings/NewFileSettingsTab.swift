import RCMMShared
import SwiftUI

struct NewFileSettingsTab: View {
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(MenuConfigStore.self) private var configStore

    private enum Layout {
        static let contentPadding = EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let config = configStore.primaryNewFileMenu {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        pageHeader(for: config)

                        NewFileMenuEditor(
                            config: config,
                            onDeleteTemplate: { templateID in
                                appCoordinator.edit {
                                    $0.removeNewFileTemplate(
                                        menuID: config.id,
                                        templateID: templateID
                                    )
                                }
                            },
                            onMoveTemplate: { source, destination in
                                appCoordinator.edit {
                                    $0.moveNewFileTemplate(
                                        menuID: config.id,
                                        from: source,
                                        to: destination
                                    )
                                }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RCMMColor.window)
    }

    private func pageHeader(for config: NewFileMenuConfig) -> some View {
        let entry = MenuEntry.newFile(config)
        let status = MenuEntryStatusResolver.status(
            for: entry,
            evaluation: MenuEntryEvaluator.evaluate(entry, environment: .filesystemAware),
            publishStates: configStore.scriptPublishStates
        )

        return RCMMPageHeader(
            title: "新建文件",
            subtitle: "配置 Finder 右键菜单中的新建文件模板"
        ) {
            HStack(spacing: 12) {
                headerStatusBadge(status)

                Toggle("已启用", isOn: Binding(
                    get: { config.isEnabled },
                    set: { isEnabled in
                        appCoordinator.edit { $0.toggleEntry(for: config.id.uuidString, isEnabled: isEnabled) }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(RCMMFont.caption)
                .foregroundStyle(RCMMColor.textMuted)
                .help(config.isEnabled ? "停用新建文件菜单" : "启用新建文件菜单")

                Button {
                    appCoordinator.edit { $0.addNewFileTemplate(to: config.id) }
                } label: {
                    Label("添加模板", systemImage: "plus")
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .controlSize(.small)
                .help("添加新模板")
            }
        }
    }

    private func headerStatusBadge(_ status: MenuEntryStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: FinderMenuStatusStyle.symbol(for: status.kind))
                .font(.system(size: 9, weight: .bold))
            Text(status.text)
                .font(RCMMFont.badge)
        }
        .foregroundStyle(FinderMenuStatusStyle.color(for: status.kind))
        .fixedSize()
        .help(status.detail ?? status.text)
    }

    private var usageTip: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(RCMMColor.accentText)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text("使用提示")
                    .font(RCMMFont.caption.weight(.semibold))
                    .foregroundStyle(RCMMColor.textSecondary)
                Text("添加模板后，可在 Finder 右键菜单中快速新建文件。")
                    .font(RCMMFont.caption)
                    .foregroundStyle(RCMMColor.textMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "document.badge.plus")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(RCMMColor.textFaint)
                .symbolRenderingMode(.hierarchical)

            Text("新建文件菜单尚未恢复")
                .font(RCMMFont.emptyTitle)
                .foregroundStyle(RCMMColor.textPrimary)

            Text("恢复后可以配置模板，并让 Finder 右键菜单创建常用文件。")
                .font(RCMMFont.secondary)
                .foregroundStyle(RCMMColor.textMuted)
                .multilineTextAlignment(.center)

            Button {
                appCoordinator.edit { store in
                    _ = store.ensureNewFileMenu()
                }
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
