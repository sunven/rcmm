import RCMMShared
import SettingsAccess
import SwiftUI

/// 正常状态弹出窗口，展示扩展状态 + 错误信息 + 打开设置 + 退出按钮
struct NormalPopoverView: View {
    @Environment(AppState.self) private var appState
    @State private var settingsHovered = false
    @State private var quitHovered = false

    var body: some View {
        VStack(spacing: 12) {
            HealthStatusPanel(status: appState.extensionStatus)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            if !appState.errorRecords.isEmpty || appState.autoRepairMessage != nil {
                Divider()
                ErrorBannerView()
            }

            Divider()

            SettingsLink {
                Text("打开设置…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } preAction: {
                ActivationPolicyManager.activateAsRegularApp()
            } postAction: {
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
        .padding(12)
    }
}

#Preview {
    NormalPopoverView()
        .environment(AppState(forPreview: true))
        .frame(width: 220)
}

#Preview("有错误") {
    let state = AppState(forPreview: true)
    state.errorRecords = [
        ErrorRecord(source: "ScriptExecutor", message: "脚本执行失败: exit code 1", context: "VS Code"),
    ]
    return NormalPopoverView()
        .environment(state)
        .frame(width: 220)
}
