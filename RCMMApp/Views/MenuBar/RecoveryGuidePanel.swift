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
    }

    private var recoveryGuideContent: some View {
        VStack(spacing: 8) {
            HealthStatusPanel(status: appState.extensionStatus)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            Divider()

            Text("Finder 扩展未启用，右键菜单功能不可用。\n请前往系统设置启用扩展。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

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
