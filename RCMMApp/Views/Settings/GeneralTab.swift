import SwiftUI
import ServiceManagement
import os.log

struct GeneralTab: View {
    @Environment(AppState.self) private var appState
    @State private var isLoginItemEnabled = false
    @State private var isUpdating = false
    @State private var errorMessage: String? = nil

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
                Button("清理旧扩展副本…") {
                    appState.beginExtensionCleanup(from: .settings)
                }
                .accessibilityLabel("清理旧扩展副本")
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: extensionCleanupSheetPresentedBinding) {
            ExtensionCleanupSheet()
                .environment(appState)
        }
        .onDisappear {
            appState.handleExtensionCleanupHostDisappear(.settings)
        }
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

    private var extensionCleanupSheetPresentedBinding: Binding<Bool> {
        Binding(
            get: {
                appState.isShowingExtensionCleanupSheet
                    && appState.extensionCleanupPresentationHost == .settings
            },
            set: { isPresented in
                if !isPresented, appState.extensionCleanupPresentationHost == .settings {
                    appState.dismissExtensionCleanupSheet()
                }
            }
        )
    }
}

// Note: Preview uses real SMAppService — status may vary in Xcode Preview context
#Preview {
    GeneralTab()
        .frame(width: 480, height: 400)
}
