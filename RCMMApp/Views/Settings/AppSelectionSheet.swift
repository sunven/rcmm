import RCMMShared
import SwiftUI

struct AppSelectionSheet: View {
    @Environment(ApplicationDiscoveryCoordinator.self) private var applicationDiscovery
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(MenuConfigStore.self) private var configStore
    @Environment(\.dismiss) private var dismiss

    var onAdded: (([UUID]) -> Void)?

    @State private var selectedAppIds: Set<UUID> = []

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
                apps: applicationDiscovery.apps,
                existingEntries: configStore.menuEntries,
                selectedAppIds: $selectedAppIds,
                isLoading: applicationDiscovery.isScanning,
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
            await applicationDiscovery.refresh()
        }
    }

    private func addSelectedApps() {
        let appsToAdd = applicationDiscovery.apps.filter { selectedAppIds.contains($0.id) }
        let addedIDs = appCoordinator.edit { $0.addMenuItems(from: appsToAdd) }
        onAdded?(addedIDs)
    }
}
