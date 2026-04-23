import RCMMShared
import SwiftUI

/// 扩展异常恢复引导面板，当 Finder 扩展未启用时显示原因说明和修复操作
///
/// 包含自动轮询检测（每 3 秒），检测到扩展恢复后显示成功确认，5 秒后自动过渡到正常视图。
struct RecoveryGuidePanel: View {
    @Environment(AppState.self) private var appState
    @State private var isRecovered = false
    @State private var pollTimer: Timer?
    @State private var transitionTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 8) {
            if isRecovered {
                recoverySuccessContent
                    .transition(.opacity)
            } else {
                recoveryGuideContent
                    .transition(.opacity)
            }
        }
        .padding(10)
        .animation(.easeInOut(duration: 0.3), value: isRecovered)
        .onAppear { startPolling() }
        .onDisappear { stopPolling() }
        .sheet(isPresented: extensionCleanupSheetPresentedBinding) {
            ExtensionCleanupSheet()
                .environment(appState)
        }
    }

    private var recoveryGuideContent: some View {
        VStack(spacing: 8) {
            HealthStatusPanel(status: appState.extensionStatus)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            Divider()

            Text(primaryRecoveryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let detail = appState.extensionStatusDetail {
                Text(detail)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(recoveryCommandHint)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("pluginkit -e use -i com.sunven.rcmm.FinderExtension")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("必要时请关闭旧的 rcmm 调试/测试版本，并重新启动 Finder。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if appState.extensionStatus == .otherInstallationEnabled {
                Button {
                    appState.beginExtensionCleanup(from: .recoveryPanel)
                } label: {
                    Text("清理旧扩展副本…")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("清理旧扩展副本")
            }

            Button {
                PluginKitService.showExtensionManagement()
            } label: {
                Text("修复")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("前往系统设置修复扩展")

            Button {
                NSApp.keyWindow?.close()
            } label: {
                Text("稍后")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("稍后修复")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("退出")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("退出 rcmm")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("扩展需要修复")
    }

    private var recoverySuccessContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("扩展已恢复")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Finder 扩展已恢复")
    }

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            Task { @MainActor in
                let status = PluginKitService.checkHealth()
                if status == .enabled {
                    stopPolling()
                    withAnimation { isRecovered = true }
                    transitionTask = Task {
                        try? await Task.sleep(for: .seconds(5))
                        appState.checkExtensionStatus()
                    }
                }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        transitionTask?.cancel()
        transitionTask = nil
    }

    private var extensionCleanupSheetPresentedBinding: Binding<Bool> {
        Binding(
            get: {
                appState.isShowingExtensionCleanupSheet
                    && appState.extensionCleanupPresentationHost == .recoveryPanel
            },
            set: { isPresented in
                if !isPresented, appState.extensionCleanupPresentationHost == .recoveryPanel {
                    appState.dismissExtensionCleanupSheet()
                }
            }
        )
    }

    private var primaryRecoveryText: String {
        switch appState.extensionStatus {
        case .otherInstallationEnabled:
            return "系统当前没有使用这份安装版 rcmm 的 Finder 扩展，因此右键菜单不会出现。请切回当前安装版扩展后再试。"
        case .disabled:
            return "Finder 扩展未启用，右键菜单功能不可用。\n请前往系统设置启用扩展。"
        case .unknown:
            return "扩展状态暂时无法确认。请重新检测，或前往系统设置检查扩展是否启用。"
        case .enabled:
            return "Finder 扩展已启用。"
        }
    }

    private var recoveryCommandHint: String {
        switch appState.extensionStatus {
        case .otherInstallationEnabled:
            return "如果系统设置里没有切回当前安装版，可先执行："
        default:
            return "如果系统设置中没有看到 rcmm，可在终端执行："
        }
    }
}

#Preview("异常状态") {
    let state = AppState(forPreview: true)
    state.extensionStatus = .disabled
    return RecoveryGuidePanel()
        .environment(state)
        .frame(width: 300)
}

#Preview("异常状态 - Dark Mode") {
    let state = AppState(forPreview: true)
    state.extensionStatus = .disabled
    return RecoveryGuidePanel()
        .environment(state)
        .frame(width: 300)
        .preferredColorScheme(.dark)
}
