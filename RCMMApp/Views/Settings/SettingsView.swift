import SwiftUI

struct SettingsView: View {

    var body: some View {
        TabView {
            MenuConfigTab()
                .tabItem {
                    Label("菜单配置", systemImage: "list.bullet")
                }
            GeneralTab()
                .tabItem {
                    Label("通用", systemImage: "gear")
                }
            AboutTab()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 400)
    }
}
