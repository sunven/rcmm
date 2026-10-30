import SwiftUI
import ServiceManagement
import os.log

struct GeneralTab: View {
    @Environment(ExtensionHealthMonitor.self) private var healthMonitor
    @Environment(AppFlowCoordinator.self) private var appFlowCoordinator
    @State private var isLoginItemEnabled = false
    @State private var isUpdating = false
    @State private var errorMessage: String? = nil
    @State private var maintenanceMessage: String? = nil
    @State private var maintenanceMessageIsError = false
    @State private var isActivatingCurrentExtension = false
    @State private var isRestartingFinder = false

    private let logger = Logger(subsystem: "com.sunven.rcmm", category: "system")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RCMMPageHeader(
                    title: "通用",
                    subtitle: "启动项、设置向导和 Finder 扩展维护"
                )

                RCMMPanel(title: "开机自启") {
                    Toggle("开机时自动启动 rcmm", isOn: $isLoginItemEnabled)
                        .font(RCMMFont.body)

                    RCMMInlineMessage(
                        isLoginItemEnabled ? "已启用：rcmm 将在开机时自动启动。" : "未启用：需要时可以从应用手动启动。",
                        kind: isLoginItemEnabled ? .success : .neutral
                    )

                    if let errorMessage {
                        RCMMInlineMessage(errorMessage, kind: .error)
                    }
                }

                RCMMPanel(title: "设置向导") {
                    Text("重新打开首次设置流程，用于检查 Finder 扩展、添加应用和设置开机自启。不会清空已有菜单配置。")
                        .font(RCMMFont.secondary)
                        .foregroundStyle(RCMMColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        appFlowCoordinator.showOnboarding()
                    } label: {
                        Label("重新打开设置向导", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                RCMMPanel(title: "扩展维护") {
                    if (healthMonitor.extensionStatus == .otherBuildEnabled
                        || healthMonitor.extensionStatus == .otherInstallationEnabled),
                       let detail = healthMonitor.extensionStatusDetail {
                        RCMMInlineMessage(detail, kind: .warning)
                            .textSelection(.enabled)
                    }

                    Text("如果 Finder 右键菜单刚更新或扩展状态异常，可以手动重启 Finder 让系统重新加载扩展。")
                        .font(RCMMFont.secondary)
                        .foregroundStyle(RCMMColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        if healthMonitor.extensionStatus == .otherBuildEnabled {
                            Button {
                                activateCurrentExtension()
                            } label: {
                                Label(
                                    isActivatingCurrentExtension ? "正在切换" : "切换到当前版本",
                                    systemImage: "arrow.triangle.swap"
                                )
                            }
                            .controlSize(.small)
                            .disabled(isActivatingCurrentExtension)
                        }

                        if healthMonitor.extensionStatus != .otherBuildEnabled {
                            Button {
                                appFlowCoordinator.beginExtensionCleanup()
                            } label: {
                                Label("清理旧扩展副本", systemImage: "trash")
                            }
                            .controlSize(.small)
                        }

                        Button {
                            restartFinder()
                        } label: {
                            Label(isRestartingFinder ? "正在重启 Finder" : "重启 Finder", systemImage: "arrow.clockwise")
                        }
                        .controlSize(.small)
                        .disabled(isRestartingFinder)

                        Spacer(minLength: 0)
                    }

                    if let maintenanceMessage {
                        RCMMInlineMessage(
                            maintenanceMessage,
                            kind: maintenanceMessageIsError ? .error : .success
                        )
                    }
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RCMMColor.window)
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
                healthMonitor.refresh()
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

    private func activateCurrentExtension() {
        guard !isActivatingCurrentExtension else { return }

        isActivatingCurrentExtension = true
        maintenanceMessage = nil
        maintenanceMessageIsError = false

        Task { @MainActor in
            do {
                try await healthMonitor.activateCurrentFinderExtension()
                maintenanceMessage = "已切换到当前版本扩展，Finder 右键菜单将只保留一份。"
                maintenanceMessageIsError = false
            } catch {
                maintenanceMessage = "切换扩展失败：\(error.localizedDescription)"
                maintenanceMessageIsError = true
                logger.error("切换当前版本扩展失败: \(error.localizedDescription)")
            }

            isActivatingCurrentExtension = false
        }
    }
}

// Note: Preview uses real SMAppService — status may vary in Xcode Preview context
#Preview {
    let appModel = AppModel(forPreview: true)

    GeneralTab()
        .environment(appModel.extensionHealthMonitor)
        .environment(appModel.appFlowCoordinator)
        .frame(width: 560, height: 480)
}
