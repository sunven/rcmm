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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                pageHeader

                GeneralSettingsPanel(title: "开机自启", systemImage: "power") {
                    Toggle("开机时自动启动 rcmm", isOn: $isLoginItemEnabled)
                        .accessibilityLabel("开机自动启动")
                        .accessibilityValue(isLoginItemEnabled ? "已启用" : "未启用")

                    InlineSettingsMessage(
                        text: isLoginItemEnabled ? "已启用：rcmm 将在开机时自动启动。" : "未启用：需要时可以从应用手动启动。",
                        kind: isLoginItemEnabled ? .success : .neutral
                    )

                    if let errorMessage {
                        InlineSettingsMessage(text: errorMessage, kind: .error)
                    }
                }

                GeneralSettingsPanel(title: "设置向导", systemImage: "checklist") {
                    Text("重新打开首次设置流程，用于检查 Finder 扩展、添加应用和设置开机自启。不会清空已有菜单配置。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        appState.showOnboarding()
                    } label: {
                        Label("重新打开设置向导", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                    .accessibilityLabel("重新打开设置向导")
                }

                GeneralSettingsPanel(title: "扩展维护", systemImage: "wrench.and.screwdriver") {
                    if appState.extensionStatus == .otherInstallationEnabled,
                       let detail = appState.extensionStatusDetail {
                        InlineSettingsMessage(text: detail, kind: .warning)
                            .textSelection(.enabled)
                    }

                    Text("如果 Finder 右键菜单刚更新或扩展状态异常，可以手动重启 Finder 让系统重新加载扩展。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button {
                            appState.beginExtensionCleanup()
                        } label: {
                            Label("清理旧扩展副本", systemImage: "trash")
                        }
                        .controlSize(.small)
                        .accessibilityLabel("清理旧扩展副本")

                        Button {
                            restartFinder()
                        } label: {
                            Label(isRestartingFinder ? "正在重启 Finder" : "重启 Finder", systemImage: "arrow.clockwise")
                        }
                        .controlSize(.small)
                        .disabled(isRestartingFinder)
                        .accessibilityLabel("重启 Finder")

                        Spacer(minLength: 0)
                    }

                    if let maintenanceMessage {
                        InlineSettingsMessage(
                            text: maintenanceMessage,
                            kind: maintenanceMessageIsError ? .error : .success
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("通用")
                .font(.title3.weight(.semibold))
            Text("启动项、设置向导和 Finder 扩展维护")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
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

private struct GeneralSettingsPanel<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 9) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.06))
            )
        }
    }
}

private enum InlineSettingsMessageKind {
    case neutral
    case success
    case warning
    case error
}

private struct InlineSettingsMessage: View {
    let text: String
    let kind: InlineSettingsMessageKind

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 14)

            Text(text)
                .font(.caption)
                .foregroundStyle(kind == .neutral ? .secondary : color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var symbolName: String {
        switch kind {
        case .neutral:
            return "info.circle"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch kind {
        case .neutral:
            return .secondary
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
