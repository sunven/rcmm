import RCMMShared
import SwiftUI

/// 正常状态弹出窗口，展示扩展状态 + 错误信息 + 打开设置 + 退出按钮
struct NormalPopoverView: View {
    @Environment(ExtensionHealthMonitor.self) private var healthMonitor
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(MenuConfigStore.self) private var configStore
    @Environment(\.dismiss) private var dismiss
    @State private var settingsHovered = false
    @State private var quitHovered = false

    var body: some View {
        VStack(spacing: 8) {
            HealthStatusPanel(status: healthMonitor.extensionStatus)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            if !configStore.errorRecords.isEmpty || appCoordinator.autoRepairMessage != nil {
                Divider()
                ErrorBannerView()
            }

            Divider()

            OpenSettingsButton(
                preAction: {
                    ActivationPolicyManager.activateAsRegularApp()
                },
                postAction: {
                    dismiss()
                    ActivationPolicyManager.refocusSettingsAfterMenuAction()
                }
            ) {
                Text("打开设置…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuItemButtonStyle())
            .environment(\.isHovered, settingsHovered)
            .onHover { settingsHovered = $0 }
            .accessibilityLabel("打开设置")
            .keyboardShortcut(",", modifiers: .command)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("退出")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(MenuItemButtonStyle())
            .environment(\.isHovered, quitHovered)
            .onHover { quitHovered = $0 }
            .accessibilityLabel("退出 rcmm")
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(10)
    }
}

#Preview {
    let appModel = AppModel(forPreview: true)

    NormalPopoverView()
        .environment(appModel.appCoordinator)
        .environment(appModel.appCoordinator.configStore)
        .environment(appModel.extensionHealthMonitor)
        .environment(appModel.appFlowCoordinator)
        .frame(width: 220)
}

#Preview("有错误") {
    let appModel = AppModel(forPreview: true)

    appModel.appCoordinator.configStore.errorRecords = [
        ErrorRecord(
            source: "ScriptExecutor",
            message: "脚本执行失败: exit code 1",
            context: "VS Code",
            kind: .scriptExecution
        ),
    ]

    return NormalPopoverView()
        .environment(appModel.appCoordinator)
        .environment(appModel.appCoordinator.configStore)
        .environment(appModel.extensionHealthMonitor)
        .environment(appModel.appFlowCoordinator)
        .frame(width: 220)
}
