import RCMMShared
import SwiftUI

struct MenuConfigTab: View {
    @Environment(AppState.self) private var appState

    @State private var showingAppSelection = false

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
                        AppListRow(
                            menuItem: item,
                            isDefault: index == 0,
                            onMoveUp: index > 0 ? { moveItem(at: index, direction: -1) } : nil,
                            onMoveDown: index < appState.menuItems.count - 1 ? { moveItem(at: index, direction: 1) } : nil,
                            position: index + 1,
                            total: appState.menuItems.count
                        )
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
}
