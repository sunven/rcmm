import SwiftUI
import RCMMShared

@main
struct rcmmApp: App {
    @State private var appState = AppState()
    @State private var appCoordinator = AppCoordinator()

    init() {
        // 在 init 中连接两者（Settings 场景不支持 onAppear）
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverContainerView()
                .environment(appState)
                .environment(appCoordinator)
                .onAppear {
                    // 连接 AppState 和 AppCoordinator
                    appState.setCoordinator(appCoordinator)
                }
        } label: {
            MenuBarStatusIcon(status: appState.extensionStatus)
        }
        .menuBarExtraStyle(.window)
        Settings {
            SettingsView()
                .environment(appState)
                .environment(appCoordinator)
                .onDisappear {
                    ActivationPolicyManager.hideToMenuBar()
                }
        }
    }
}
