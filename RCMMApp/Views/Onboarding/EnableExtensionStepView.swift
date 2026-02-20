import SwiftUI

struct EnableExtensionStepView: View {
    @Binding var isExtensionEnabled: Bool
    var onNext: () -> Void

    @State private var timerCancellable: Timer?

    var body: some View {
        VStack(spacing: 24) {
            // 顶部图标和标题
            VStack(spacing: 12) {
                Image(systemName: "puzzlepiece.extension.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)

                Text("启用 Finder 扩展")
                    .font(.title2.bold())

                Text("rcmm 需要启用 Finder Sync 扩展才能在右键菜单中显示快捷操作。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Divider()

            // 说明文字（适配 macOS 版本）
            VStack(alignment: .leading, spacing: 8) {
                Text("请在系统设置中启用扩展：")
                    .font(.subheadline.bold())

                if #available(macOS 15.2, *) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("打开 系统设置", systemImage: "1.circle.fill")
                        Label("前往 通用 > 登录项与扩展", systemImage: "2.circle.fill")
                        Label("找到 rcmm 并开启扩展", systemImage: "3.circle.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("点击下方「前往系统设置」按钮", systemImage: "1.circle.fill")
                        Label("在扩展列表中找到 rcmm 并开启", systemImage: "2.circle.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text("如果系统设置中未显示扩展选项，可在终端中执行：")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                    Text("pluginkit -e use -i com.sunven.rcmm.FinderExtension")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            // 状态显示
            if isExtensionEnabled {
                Label("Extension 已启用", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Finder 扩展已成功启用")
            }

            Spacer()

            // 操作按钮
            VStack(spacing: 12) {
                Button {
                    PluginKitService.showExtensionManagement()
                } label: {
                    Text("前往系统设置")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel("打开系统设置中的扩展管理页面")

                Button {
                    checkExtensionStatus()
                } label: {
                    Text("重新检测")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("手动检测 Finder 扩展状态")
            }
            .padding(.horizontal)
        }
        .onAppear {
            checkExtensionStatus()
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
    }

    private func checkExtensionStatus() {
        let enabled = PluginKitService.isExtensionEnabled
        isExtensionEnabled = enabled
        if enabled {
            stopPolling()
            onNext()
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
    .frame(width: 440, height: 420)
}

#Preview("已启用") {
    EnableExtensionStepView(
        isExtensionEnabled: .constant(true),
        onNext: {}
    )
    .frame(width: 440, height: 420)
}
