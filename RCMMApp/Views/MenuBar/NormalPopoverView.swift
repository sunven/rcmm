import SettingsAccess
import SwiftUI

/// 正常状态弹出窗口，展示扩展状态 + 打开设置 + 退出按钮
struct NormalPopoverView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 12) {
            HealthStatusPanel(status: appState.extensionStatus)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            Divider()

            SettingsLink {
                Text("打开设置…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } preAction: {
                ActivationPolicyManager.activateAsRegularApp()
            } postAction: {
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开设置")
            .keyboardShortcut(",", modifiers: .command)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("退出")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("退出 rcmm")
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(12)
    }
}

#Preview {
    NormalPopoverView()
        .environment(AppState(forPreview: true))
        .frame(width: 300)
}
