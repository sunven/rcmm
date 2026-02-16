import SwiftUI
import RCMMShared

@main
struct rcmmApp: App {
    init() {
        setupInitialConfig()
    }

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

    /// 初始化硬编码配置和安装脚本
    private func setupInitialConfig() {
        let configService = SharedConfigService()

        // 检查是否已有配置（UserDefaults 读取 < 1ms，同步执行确保 Extension 可读）
        let existingItems = configService.load()
        let items: [MenuItemConfig]

        if existingItems.isEmpty {
            // 首次启动：创建硬编码 Terminal 配置
            let terminalConfig = MenuItemConfig(
                appName: "Terminal",
                bundleId: "com.apple.Terminal",
                appPath: "/Applications/Utilities/Terminal.app",
                sortOrder: 0
            )
            configService.save([terminalConfig])
            items = [terminalConfig]
        } else {
            items = existingItems
        }

        // 脚本编译 (osacompile) 可能阻塞，移至后台线程避免启动延迟
        DispatchQueue.global(qos: .userInitiated).async {
            let scriptInstaller = ScriptInstallerService()
            scriptInstaller.syncScripts(with: items)
            DarwinNotificationCenter.shared.post(NotificationNames.configChanged)
        }
    }
}
