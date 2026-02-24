import SettingsAccess
import SwiftUI
import RCMMShared

@main
struct rcmmApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            PopoverContainerView()
                .environment(appState)
        } label: {
            MenuBarStatusIcon(status: appState.extensionStatus)
        }
        .menuBarExtraStyle(.window)
        Settings {
            SettingsView()
                .environment(appState)
                .onDisappear {
                    ActivationPolicyManager.hideToMenuBar()
                }
        }
    }
}
