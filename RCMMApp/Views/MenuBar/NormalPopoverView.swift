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

    private var enabledCount: Int {
        configStore.menuEntries.filter(\.isEnabled).count
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            RCMMDivider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 6) {
                HealthStatusPanel(status: healthMonitor.extensionStatus)

                Text("\(configStore.menuEntries.count) 个菜单项 · \(enabledCount) 个启用")
                    .font(RCMMFont.caption)
                    .monospacedDigit()
                    .foregroundStyle(RCMMColor.textMuted)
                    .padding(.leading, 22)
            }

            if !configStore.errorRecords.isEmpty || appCoordinator.autoRepairMessage != nil {
                RCMMDivider()
                    .padding(.vertical, 8)
                ErrorBannerView()
            }

            RCMMDivider()
                .padding(.top, 8)
                .padding(.bottom, 6)

            OpenSettingsButton(
                preAction: {
                    ActivationPolicyManager.activateAsRegularApp()
                },
                postAction: {
                    dismiss()
                    ActivationPolicyManager.refocusSettingsAfterMenuAction()
                }
            ) {
                menuRowLabel("打开设置…", systemImage: "gearshape", shortcut: "⌘,")
            }
            .buttonStyle(MenuItemButtonStyle())
            .environment(\.isHovered, settingsHovered)
            .onHover { settingsHovered = $0 }
            .keyboardShortcut(",", modifiers: .command)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                menuRowLabel("退出 rcmm", systemImage: "power", shortcut: "⌘Q")
            }
            .buttonStyle(MenuItemButtonStyle())
            .environment(\.isHovered, quitHovered)
            .onHover { quitHovered = $0 }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                Text("rcmm")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Finder 右键菜单")
                    .font(RCMMFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private func menuRowLabel(_ title: String, systemImage: String, shortcut: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(RCMMColor.textMuted)
                .frame(width: 16)

            Text(title)
                .font(RCMMFont.body)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Text(shortcut)
                .font(RCMMFont.caption)
                .foregroundStyle(RCMMColor.textFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let appModel = AppModel(forPreview: true)

    NormalPopoverView()
        .environment(appModel.appCoordinator)
        .environment(appModel.appCoordinator.configStore)
        .environment(appModel.extensionHealthMonitor)
        .environment(appModel.appFlowCoordinator)
        .frame(width: 260)
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
        .frame(width: 380)
}
