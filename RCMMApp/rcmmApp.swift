import SwiftUI

@main
struct rcmmApp: App {
    var body: some Scene {
        MenuBarExtra("rcmm", systemImage: "contextualmenu.and.cursorarrow") {
            Text("rcmm is running")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        Settings {
            Text("Settings")
                .frame(width: 300, height: 200)
        }
    }
}
