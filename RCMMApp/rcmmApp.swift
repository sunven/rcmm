import SwiftUI
import RCMMShared

@main
struct rcmmApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverContainerView()
                .environment(appModel.appState)
                .environment(appModel.appCoordinator)
        } label: {
            MenuBarStatusIcon(status: appModel.appState.extensionStatus)
        }
        .menuBarExtraStyle(.window)
        Settings {
            SettingsView()
                .environment(appModel.appState)
                .environment(appModel.appCoordinator)
                .onDisappear {
                    ActivationPolicyManager.hideToMenuBar()
                }
        }
    }
}
