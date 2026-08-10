import RCMMShared
import SwiftUI

struct SelectAppsStepView: View {
    @Binding var selectedAppIds: Set<UUID>
    @Environment(ApplicationDiscoveryCoordinator.self) private var applicationDiscovery
    @Environment(MenuConfigStore.self) private var configStore

    private let preselectBundleIds: Set<String> = [
        "com.apple.Terminal",
        "com.microsoft.VSCode",
        "com.googlecode.iterm2",
    ]

    var body: some View {
        VStack(spacing: 0) {
            AppPickerListView(
                apps: applicationDiscovery.apps,
                existingEntries: configStore.menuEntries,
                selectedAppIds: $selectedAppIds,
                isLoading: applicationDiscovery.isScanning,
                loadingTitle: "正在扫描已安装应用...",
                emptyTitle: "未发现可用应用",
                emptySubtitle: "仅显示 /Applications 和 ~/Applications 中的应用"
            )

            if !applicationDiscovery.isScanning && !applicationDiscovery.apps.isEmpty {
                HStack {
                    Text("已选择 \(selectedAppIds.count) 个应用")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("已选择 \(selectedAppIds.count) 个应用")

                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
        }
        .task {
            await loadAndPreselectApps()
        }
    }

    // MARK: - Actions

    private func loadAndPreselectApps() async {
        await applicationDiscovery.refresh()

        for app in applicationDiscovery.apps {
            if let bundleId = app.bundleId,
               preselectBundleIds.contains(bundleId),
               !AppPickerItemMatcher.isAlreadyAdded(app, in: configStore.menuEntries) {
                selectedAppIds.insert(app.id)
            }
        }
    }
}

#Preview("加载中") {
    let appModel = AppModel(forPreview: true)

    SelectAppsStepView(selectedAppIds: .constant([]))
        .environment(appModel.applicationDiscoveryCoordinator)
        .environment(appModel.appCoordinator.configStore)
        .frame(width: 480, height: 500)
}

#Preview("列表状态") {
    let appModel = AppModel(forPreview: true)
    let sampleApps = [
        AppInfo(name: "Terminal", bundleId: "com.apple.Terminal", path: "/System/Applications/Utilities/Terminal.app", category: .terminal),
        AppInfo(name: "iTerm", bundleId: "com.googlecode.iterm2", path: "/Applications/iTerm.app", category: .terminal),
        AppInfo(name: "Visual Studio Code", bundleId: "com.microsoft.VSCode", path: "/Applications/Visual Studio Code.app", category: .editor),
    ]
    let coordinator = ApplicationDiscoveryCoordinator(
        scanApplications: { sampleApps },
        addComposite: { $0.id }
    )
    let sampleId = sampleApps.first!.id
    return SelectAppsStepView(selectedAppIds: .constant([sampleId]))
        .environment(coordinator)
        .environment(appModel.appCoordinator.configStore)
        .frame(width: 480, height: 500)
}
