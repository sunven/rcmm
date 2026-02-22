import RCMMShared
import SwiftUI

struct MenuConfigTab: View {
    @Environment(AppState.self) private var appState

    @State private var showingAppSelection = false
    @State private var expandedItems: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            if appState.menuItems.isEmpty {
                Spacer()
                Text("暂无菜单项")
                    .foregroundStyle(.secondary)
                Text("点击下方按钮添加应用")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                List {
                    ForEach(Array(appState.menuItems.enumerated()), id: \.element.id) { index, item in
                        DisclosureGroup(isExpanded: expandedBinding(for: item.id)) {
                            CommandEditor(
                                editedCommand: item.customCommand ?? "",
                                defaultCommand: resolveDefaultCommand(for: item),
                                appPath: item.appPath,
                                onSave: { command in
                                    appState.updateCustomCommand(for: item.id, command: command)
                                }
                            )
                        } label: {
                            AppListRow(
                                menuItem: item,
                                isDefault: index == 0,
                                onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                                onMoveDown: index < appState.menuItems.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                                position: index + 1,
                                total: appState.menuItems.count
                            )
                        }
                    }
                    .onMove { source, destination in
                        appState.moveMenuItem(from: source, to: destination)
                    }
                    .onDelete { offsets in
                        appState.removeMenuItem(at: offsets)
                    }
                }
            }

            Divider()

            HStack {
                Button("添加应用") {
                    showingAppSelection = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("添加应用到右键菜单")

                Button("手动添加") {
                    selectManually()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("手动选择应用文件")

                Spacer()
            }
            .padding()
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

    /// VoiceOver 辅助排序：将指定位置的项上移或下移一位
    private func moveItem(at index: Int, direction: Int) {
        let destination = direction < 0 ? index - 1 : index + 2
        appState.moveMenuItem(from: IndexSet(integer: index), to: destination)
    }

    /// 为指定列表项生成独立的展开状态 binding
    private func expandedBinding(for id: UUID) -> Binding<Bool> {
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

    /// 解析当前生效的命令（内置映射或默认 open -a），用作 CommandEditor 的 placeholder
    private func resolveDefaultCommand(for item: MenuItemConfig) -> String {
        if let builtIn = CommandMappingService.command(for: item.bundleId) {
            return builtIn
        }
        return "open -a \"\(item.appPath)\" {path}"
    }
}
