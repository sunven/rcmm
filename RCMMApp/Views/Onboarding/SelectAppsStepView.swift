import RCMMShared
import SwiftUI

struct SelectAppsStepView: View {
    @Binding var selectedAppIds: Set<UUID>
    @Binding var didPreselectApps: Bool
    @Environment(ApplicationDiscoveryCoordinator.self) private var applicationDiscovery
    @Environment(MenuConfigStore.self) private var configStore

    private let preselectBundleIds: Set<String> = [
        "com.apple.Terminal",
        "com.microsoft.VSCode",
        "com.googlecode.iterm2",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("选择常用应用")
                    .font(RCMMFont.pageTitle)
                    .foregroundStyle(RCMMColor.textPrimary)

                Text("选中的应用会加入 Finder 右键菜单，之后可以在设置中调整顺序。")
                    .font(RCMMFont.secondary)
                    .foregroundStyle(RCMMColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AppPickerListView(
                apps: applicationDiscovery.apps,
                existingEntries: configStore.menuEntries,
                selectedAppIds: $selectedAppIds,
                isLoading: applicationDiscovery.isScanning,
                loadingTitle: "正在扫描已安装应用…",
                emptyTitle: "未发现可用应用",
                emptySubtitle: "仅显示 /Applications 和 ~/Applications 中的应用"
            )

            HStack(spacing: 6) {
                Text("已选择 \(selectedAppIds.count) 个应用")
                    .font(RCMMFont.caption)
                    .monospacedDigit()
                    .foregroundStyle(selectedAppIds.isEmpty ? RCMMColor.textMuted : RCMMColor.accentText)

                Spacer()

                Text("已添加的应用会保留")
                    .font(RCMMFont.caption)
                    .foregroundStyle(RCMMColor.textFaint)
            }
        }
        .task {
            await loadAndPreselectApps()
        }
    }

    // MARK: - Actions

    private func loadAndPreselectApps() async {
        await applicationDiscovery.refresh()
        guard !Task.isCancelled else { return }
        let availableIDs = Set(applicationDiscovery.apps.filter {
            !AppPickerItemMatcher.isAlreadyAdded($0, in: configStore.menuEntries)
        }.map(\.id))
        selectedAppIds.formIntersection(availableIDs)
        guard !didPreselectApps else { return }
        didPreselectApps = true

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

    SelectAppsStepView(selectedAppIds: .constant([]), didPreselectApps: .constant(false))
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
    return SelectAppsStepView(selectedAppIds: .constant([sampleId]), didPreselectApps: .constant(false))
        .environment(coordinator)
        .environment(appModel.appCoordinator.configStore)
        .frame(width: 480, height: 500)
}
