import RCMMShared
import SwiftUI

struct MenuConfigTab: View {
    @Environment(AppState.self) private var appState

    @State private var showingAppSelection = false
    @State private var expandedItems: Set<String> = []

    private enum Layout {
        static let rowInsets = EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10)
        static let footerPadding = EdgeInsets(top: 10, leading: 12, bottom: 12, trailing: 12)
    }

    var body: some View {
        VStack(spacing: 0) {
            if appState.menuEntries.isEmpty {
                VStack(spacing: 4) {
                    Text("暂无菜单项")
                        .foregroundStyle(.secondary)
                    Text("点击下方按钮添加应用")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(appState.menuEntries.enumerated()), id: \.element.id) { index, entry in
                        switch entry {
                        case .builtIn(let item):
                            BuiltInListRow(
                                item: item,
                                onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                                onMoveDown: index < appState.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                                onToggle: { isEnabled in
                                    appState.toggleEntry(for: entry.id, isEnabled: isEnabled)
                                },
                                position: index + 1,
                                total: appState.menuEntries.count
                            )
                            .listRowInsets(Layout.rowInsets)
                            .listRowSeparator(.hidden)
                        case .custom(let config):
                            DisclosureGroup(isExpanded: expandedBinding(for: entry.id)) {
                                CommandEditor(
                                    editedCommand: config.customCommand ?? "",
                                    defaultCommand: resolveDefaultCommand(for: config),
                                    appPath: config.appPath,
                                    onSave: { command in
                                        appState.updateCustomCommand(for: config.id, command: command)
                                    }
                                )
                                .padding(.top, 4)
                            } label: {
                                AppListRow(
                                    menuItem: config,
                                    onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                                    onMoveDown: index < appState.menuEntries.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                                    onDelete: { appState.removeEntry(at: IndexSet(integer: index)) },
                                    onToggle: { isEnabled in
                                        appState.toggleEntry(for: entry.id, isEnabled: isEnabled)
                                    },
                                    position: index + 1,
                                    total: appState.menuEntries.count
                                )
                            }
                            .listRowInsets(Layout.rowInsets)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .onMove { source, destination in
                        appState.moveEntry(from: source, to: destination)
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button("添加应用") {
                    showingAppSelection = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("添加应用到右键菜单")

                Button("手动添加") {
                    selectManually()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("手动选择应用文件")

                Spacer()
            }
            .padding(Layout.footerPadding)
        }
        .sheet(isPresented: $showingAppSelection) {
            AppSelectionSheet()
        }
    }

    private func selectManually() {
        Task { @MainActor in
            let discoveryService = AppDiscoveryService()
            if let appInfo = await discoveryService.selectApplicationManually() {
                guard !appState.containsApp(bundleId: appInfo.bundleId, appPath: appInfo.path) else {
                    return
                }
                appState.addMenuItem(from: appInfo)
            }
        }
    }

    private func moveItem(at index: Int, direction: Int) {
        let destination = direction < 0 ? index - 1 : index + 2
        appState.moveEntry(from: IndexSet(integer: index), to: destination)
    }

    private func expandedBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedItems.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedItems.insert(id)
                } else {
                    expandedItems.remove(id)
                }
            }
        )
    }

    private func resolveDefaultCommand(for item: MenuItemConfig) -> String {
        if let builtIn = CommandMappingService.command(for: item.bundleId) {
            return builtIn
        }
        return "open -a \"\(item.appPath)\" {path}"
    }
}
