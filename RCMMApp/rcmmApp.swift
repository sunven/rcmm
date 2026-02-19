import SettingsAccess
import SwiftUI
import RCMMShared

@main
struct rcmmApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("rcmm", systemImage: "contextualmenu.and.cursorarrow") {
            SettingsLink {
                Text("设置…")
            } preAction: {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            } postAction: {
            }
            .keyboardShortcut(",", modifiers: .command)
            Divider()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        Settings {
            SettingsView()
                .environment(appState)
                .onDisappear {
                    DispatchQueue.main.async {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }
    }
}
