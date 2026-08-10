import RCMMShared
import SwiftUI

/// 错误展示横幅，在弹出窗口中显示最近的执行错误和恢复建议
struct ErrorBannerView: View {
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(MenuConfigStore.self) private var configStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAutoRepair = true

    /// 最多展示 3 条最近的错误，避免弹出窗口过高
    private var displayedErrors: [ErrorRecord] {
        Array(configStore.errorRecords.suffix(3))
    }

    var body: some View {
        VStack(spacing: 8) {
            if let message = appCoordinator.autoRepairMessage, showAutoRepair {
                autoRepairBanner(message: message)
                    .transition(.opacity)
            }

            ForEach(displayedErrors) { record in
                errorRow(record: record)
            }

            if !configStore.errorRecords.isEmpty {
                actionBar
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showAutoRepair)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("错误信息")
    }

    private func autoRepairBanner(message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            try? await Task.sleep(for: .seconds(5))
            showAutoRepair = false
            appCoordinator.clearAutoRepairMessage()
        }
    }

    private func errorRow(record: ErrorRecord) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.caption)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if let context = record.context {
                    Text(context)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Text(record.message)
                    .font(.caption)
                    .foregroundStyle(.red)
                Text(recoveryAdvice(for: record))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.context ?? "")，\(record.message)，\(recoveryAdvice(for: record))")
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            OpenSettingsButton(
                preAction: {
                    ActivationPolicyManager.activateAsRegularApp()
                },
                postAction: {
                    dismiss()
                    ActivationPolicyManager.refocusSettingsAfterMenuAction()
                }
            ) {
                Text("打开设置")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .controlSize(.small)
            .accessibilityLabel("打开设置以修复问题")

            Button {
                appCoordinator.dismissAllErrors()
            } label: {
                Text("忽略全部")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("忽略所有错误")
        }
    }

    private func recoveryAdvice(for record: ErrorRecord) -> String {
        switch record.kind {
        case .scriptCompile:
            return "请在设置中检查命令内容"
        case .scriptPublish:
            return "请检查脚本目录权限后重试"
        case .scriptLoad:
            return "请重试；如仍失败，请打开设置检查"
        case .scriptExecution:
            return "请检查菜单配置和目标路径"
        case nil:
            return "请在设置中检查菜单配置"
        }
    }
}

#Preview("有错误") {
    let appModel = AppModel(forPreview: true)

    // 直接设置到 configStore
    appModel.appCoordinator.configStore.errorRecords = [
        ErrorRecord(
            source: "extension",
            message: "脚本执行失败: exit code 1",
            context: "VS Code",
            kind: .scriptExecution
        ),
        ErrorRecord(
            source: "extension",
            message: "脚本文件不存在或无法加载: vscode.scpt",
            context: "VS Code",
            kind: .scriptLoad
        ),
    ]

    return ErrorBannerView()
        .environment(appModel.appCoordinator)
        .environment(appModel.appCoordinator.configStore)
        .frame(width: 196)
        .padding()
}

#Preview("有自动修复消息") {
    let appModel = AppModel(forPreview: true)

    appModel.appCoordinator.configStore.errorRecords = [
        ErrorRecord(
            source: "extension",
            message: "脚本文件不存在或无法加载: vscode.scpt",
            context: "VS Code",
            kind: .scriptLoad
        ),
    ]
    appModel.appCoordinator.autoRepairMessage = "已自动修复脚本文件"

    return ErrorBannerView()
        .environment(appModel.appCoordinator)
        .environment(appModel.appCoordinator.configStore)
        .frame(width: 196)
        .padding()
}

#Preview("无错误") {
    let appModel = AppModel(forPreview: true)

    return ErrorBannerView()
        .environment(appModel.appCoordinator)
        .environment(appModel.appCoordinator.configStore)
        .frame(width: 196)
        .padding()
}
