import SettingsAccess
import SwiftUI
import RCMMShared

@main
struct rcmmApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("rcmm", systemImage: "contextualmenu.and.cursorarrow") {
            PopoverContainerView()
                .environment(appState)
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
