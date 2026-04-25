import SwiftUI
import ServiceManagement
import os.log

struct GeneralTab: View {
    @Environment(AppState.self) private var appState
    @State private var isLoginItemEnabled = false
    @State private var isUpdating = false
    @State private var errorMessage: String? = nil
    @State private var maintenanceMessage: String? = nil
    @State private var maintenanceMessageIsError = false
    @State private var isRestartingFinder = false

    private let logger = Logger(subsystem: "com.sunven.rcmm", category: "system")

    var body: some View {
        Form {
            Section("开机自启") {
                Toggle("开机时自动启动 rcmm", isOn: $isLoginItemEnabled)
                    .accessibilityLabel("开机自动启动")
                    .accessibilityValue(isLoginItemEnabled ? "已启用" : "未启用")

                Text(isLoginItemEnabled ? "已启用 — rcmm 将在开机时自动启动" : "未启用")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("扩展维护") {
                if appState.extensionStatus == .otherInstallationEnabled,
                   let detail = appState.extensionStatusDetail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Text("如果 Finder 右键菜单刚更新或扩展状态异常，可以手动重启 Finder 让系统重新加载扩展。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("清理旧扩展副本…") {
                    appState.beginExtensionCleanup()
                }
                .accessibilityLabel("清理旧扩展副本")

                Button(isRestartingFinder ? "正在重启 Finder…" : "重启 Finder") {
                    restartFinder()
                }
                .disabled(isRestartingFinder)
                .accessibilityLabel("重启 Finder")

                if let maintenanceMessage {
                    Text(maintenanceMessage)
                        .font(.caption)
                        .foregroundStyle(maintenanceMessageIsError ? .red : .secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            isUpdating = true
            isLoginItemEnabled = SMAppService.mainApp.status == .enabled
            errorMessage = nil
            Task { @MainActor in
                if isUpdating {
                    isUpdating = false
                }
            }
        }
        .onChange(of: isLoginItemEnabled) { _, newValue in
            if isUpdating {
                isUpdating = false
                return
            }
            isUpdating = true

            do {
                if newValue {
                    try SMAppService.mainApp.register()
                    logger.info("开机自启已启用")
                } else {
                    try SMAppService.mainApp.unregister()
                    logger.info("开机自启已关闭")
                }
                errorMessage = nil
                isUpdating = false
            } catch {
                isLoginItemEnabled = !newValue
                errorMessage = "操作失败：\(error.localizedDescription)"
                logger.error("开机自启操作失败: \(error.localizedDescription)")
            }
        }
    }

    private func restartFinder() {
        guard !isRestartingFinder else { return }

        isRestartingFinder = true
        maintenanceMessage = nil
        maintenanceMessageIsError = false

        Task { @MainActor in
            do {
                try await Task.detached(priority: .userInitiated) {
                    try PluginKitService.restartFinder()
                }.value
                try? await Task.sleep(for: .seconds(1))
                appState.checkExtensionStatus()
                maintenanceMessage = "Finder 已重启，可以回到 Finder 再试一次右键菜单。"
                maintenanceMessageIsError = false
                logger.info("Finder 已通过设置页手动重启")
            } catch {
                maintenanceMessage = "重启 Finder 失败：\(error.localizedDescription)"
                maintenanceMessageIsError = true
                logger.error("重启 Finder 失败: \(error.localizedDescription)")
            }

            isRestartingFinder = false
        }
    }
}

// Note: Preview uses real SMAppService — status may vary in Xcode Preview context
#Preview {
    GeneralTab()
        .frame(width: 480, height: 400)
}
