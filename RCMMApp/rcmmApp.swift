import SwiftUI
import RCMMShared

@main
struct rcmmApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverContainerView()
                .environment(appModel.appCoordinator)
                .environment(appModel.appCoordinator.configStore)
                .environment(appModel.extensionHealthMonitor)
                .environment(appModel.appFlowCoordinator)
        } label: {
            MenuBarStatusIcon(status: appModel.extensionHealthMonitor.extensionStatus)
        }
        .menuBarExtraStyle(.window)
        Settings {
            SettingsView()
                .environment(appModel.appCoordinator)
                .environment(appModel.appCoordinator.configStore)
                .environment(appModel.updateCoordinator)
                .environment(appModel.extensionHealthMonitor)
                .environment(appModel.appFlowCoordinator)
                .environment(appModel.applicationDiscoveryCoordinator)
                .onDisappear {
                    ActivationPolicyManager.hideToMenuBar()
                }
        }
    }
}
