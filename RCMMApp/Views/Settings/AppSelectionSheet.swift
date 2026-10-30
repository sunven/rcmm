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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("选择应用")
                        .font(RCMMFont.sheetTitle)
                        .foregroundStyle(RCMMColor.textPrimary)
                    Text("仅显示 /Applications 和 ~/Applications 中的应用")
                        .font(RCMMFont.caption)
                        .foregroundStyle(RCMMColor.textMuted)
                }

                Spacer()

                if !selectedAppIds.isEmpty {
                    Text("已选择 \(selectedAppIds.count) 个")
                        .font(RCMMFont.caption)
                        .monospacedDigit()
                        .foregroundStyle(RCMMColor.accentText)
                }
            }
            .padding(16)

            RCMMDivider()

            AppPickerListView(
                apps: applicationDiscovery.apps,
                existingEntries: configStore.menuEntries,
                selectedAppIds: $selectedAppIds,
                isLoading: applicationDiscovery.isScanning,
                loadingTitle: "正在扫描应用…",
                emptyTitle: "未发现可添加应用",
                emptySubtitle: "仅支持从 /Applications 和 ~/Applications 添加应用"
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            RCMMDivider()

            HStack {
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(selectedAppIds.isEmpty ? "确认添加" : "添加 \(selectedAppIds.count) 个应用") {
                    addSelectedApps()
                    dismiss()
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(selectedAppIds.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 420, height: 520)
        .background(RCMMColor.window)
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
