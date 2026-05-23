import RCMMShared
import SwiftUI

struct AppSelectionSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var onAdded: (([UUID]) -> Void)?

    @State private var discoveredApps: [AppInfo] = []
    @State private var selectedAppIds: Set<UUID> = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("选择应用")
                    .font(.headline)
                Text("仅显示 /Applications 和 ~/Applications 中的应用")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            AppPickerListView(
                apps: discoveredApps,
                existingEntries: appState.menuEntries,
                selectedAppIds: $selectedAppIds,
                isLoading: isLoading,
                loadingTitle: "正在扫描应用…",
                emptyTitle: "未发现可添加应用",
                emptySubtitle: "仅支持从 /Applications 和 ~/Applications 添加应用"
            )

            Divider()

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("确认添加") {
                    addSelectedApps()
                    dismiss()
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(selectedAppIds.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .task {
            await loadApps()
        }
    }

    private func loadApps() async {
        isLoading = true
        let discoveryService = AppDiscoveryService()
        let apps = await Task.detached {
            discoveryService.scanApplications()
        }.value
        discoveredApps = apps
        appState.discoveredApps = apps
        isLoading = false
    }

    private func addSelectedApps() {
        let appsToAdd = discoveredApps.filter { selectedAppIds.contains($0.id) }
        let addedIDs = appState.addMenuItems(from: appsToAdd)
        onAdded?(addedIDs)
    }
}
