import RCMMShared
import SwiftUI

struct EnableExtensionStepView: View {
    @Binding var isExtensionEnabled: Bool
    var autoAdvanceWhenEnabled = true
    var onNext: () -> Void

    @State private var timerCancellable: Timer?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("启用 Finder 扩展")
                    .font(RCMMFont.pageTitle)
                    .foregroundStyle(RCMMColor.textPrimary)

                Text("\(PluginKitService.appDisplayName) 需要启用 Finder Sync 扩展，才会出现在右键菜单中。")
                    .font(RCMMFont.secondary)
                    .foregroundStyle(RCMMColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            RCMMPanel(title: "在系统设置中启用") {
                if #available(macOS 15.2, *) {
                    instructionRow(1, "打开 系统设置")
                    instructionRow(2, "前往 通用 > 登录项与扩展")
                    instructionRow(3, "找到 \(PluginKitService.appDisplayName) 并开启扩展")
                } else {
                    instructionRow(1, "点击下方「前往系统设置」按钮")
                    instructionRow(2, "在扩展列表中找到 \(PluginKitService.appDisplayName) 并开启")

                    VStack(alignment: .leading, spacing: 4) {
                        Text("如果系统设置中未显示扩展选项，可在终端中执行：")
                            .font(RCMMFont.caption)
                            .foregroundStyle(RCMMColor.textMuted)
                            .padding(.top, 4)
                        RCMMCodeBlock(text: PluginKitService.extensionEnableCommand)
                    }
                }

                if isExtensionEnabled {
                    RCMMInlineMessage("Finder 扩展已启用", kind: .success)
                }
            }

            RCMMPanel(title: "启用后") {
                benefitRow("Finder 右键菜单会显示你添加的应用和命令。")
                benefitRow("扩展只读取 rcmm 的菜单配置，不会改动 Finder 本身。")
                benefitRow("可随时在系统设置中关闭扩展，右键菜单立即恢复原样。")
            }

            HStack(spacing: 8) {
                Button {
                    PluginKitService.showExtensionManagement()
                } label: {
                    Label("前往系统设置", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .controlSize(.regular)

                Button {
                    checkExtensionStatus()
                } label: {
                    Label("重新检测", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Spacer(minLength: 0)
        }
        .onAppear {
            checkExtensionStatus()
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }

    private func instructionRow(_ index: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(index)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(RCMMColor.accentText)
                .frame(width: 16, height: 16)
                .background(Circle().fill(RCMMColor.accentSoft))

            Text(text)
                .font(RCMMFont.secondary)
                .foregroundStyle(RCMMColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func benefitRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(RCMMColor.accentText)
                .frame(width: 16)

            Text(text)
                .font(RCMMFont.secondary)
                .foregroundStyle(RCMMColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func checkExtensionStatus() {
        let enabled = PluginKitService.isExtensionEnabled
        isExtensionEnabled = enabled
        if enabled {
            stopPolling()
            if autoAdvanceWhenEnabled {
                onNext()
            }
        }
    }

    private func startPolling() {
        stopPolling()
        timerCancellable = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            Task { @MainActor in
                checkExtensionStatus()
            }
        }
    }

    private func stopPolling() {
        timerCancellable?.invalidate()
        timerCancellable = nil
    }
}

#Preview("未启用") {
    EnableExtensionStepView(
        isExtensionEnabled: .constant(false),
        onNext: {}
    )
    .padding(24)
    .frame(width: 460, height: 440)
    .background(RCMMColor.window)
}

#Preview("已启用") {
    EnableExtensionStepView(
        isExtensionEnabled: .constant(true),
        onNext: {}
    )
    .padding(24)
    .frame(width: 460, height: 440)
    .background(RCMMColor.window)
}
