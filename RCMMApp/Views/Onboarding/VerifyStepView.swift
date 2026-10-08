import AppKit
import RCMMShared
import SwiftUI

struct VerifyStepView: View {
    @Binding var launchAtLogin: Bool
    let verification: OnboardingVerification
    @Environment(AppCoordinator.self) private var appCoordinator
    @Environment(MenuConfigStore.self) private var configStore
    @State private var showsRecovery = false
    @State private var directoryError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("验证 Finder 右键菜单")
                .font(.title2.bold())
                .frame(maxWidth: .infinity)

            if verification.phase == .syncing {
                ProgressView("正在同步所选应用…")
            } else if verification.isReady(in: configStore) {
                Label("配置已同步，请在 Finder 中验证", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("配置尚未同步成功", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            ForEach(verification.items(in: configStore)) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Label(item.name, systemImage: verification.phase == .syncing ? "arrow.triangle.2.circlepath" : (item.issue == nil ? "checkmark.circle" : "exclamationmark.triangle"))
                    if verification.phase != .syncing, let issue = item.issue {
                        Text(issue)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .textSelection(.enabled)
                    }
                }
            }

            if verification.targets.isEmpty {
                Text("请返回上一步添加应用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label("打开测试目录，在空白处右键", systemImage: "1.circle.fill")
                Label("点击上方列出的任意一个应用", systemImage: "2.circle.fill")
                Label("确认应用打开到测试目录", systemImage: "3.circle.fill")
                Text("如使用子菜单模式，请先展开 rcmm 菜单。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            Button("打开测试目录", action: openTestDirectory)
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(!verification.isReady(in: configStore))

            if let directoryError {
                Text(directoryError)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Toggle("已在 Finder 中成功打开应用", isOn: Binding(
                get: { verification.isConfirmed(in: configStore) },
                set: { verification.confirm($0, in: configStore) }
            ))
            .toggleStyle(.checkbox)
            .disabled(!verification.isReady(in: configStore))

            if verification.phase != .syncing && !verification.isReady(in: configStore) {
                retryButton
            }

            DisclosureGroup("菜单未出现", isExpanded: $showsRecovery) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("先关闭 Finder 右键菜单，重新打开；如仍未出现，请确认系统设置中已启用当前版本的 Finder 扩展。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        retryButton
                        Button("前往系统设置") {
                            PluginKitService.showExtensionManagement()
                        }
                    }
                }
                .padding(.top, 6)
            }

            Divider()

            Toggle("开机自动启动", isOn: $launchAtLogin)
                .toggleStyle(.switch)
        }
    }

    private var retryButton: some View {
        Button("重新同步") {
            verification.retry(coordinator: appCoordinator)
        }
        .disabled(verification.phase == .syncing || verification.targets.isEmpty)
    }

    private func openTestDirectory() {
        directoryError = nil
        do {
            let caches = try FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = caches
                .appendingPathComponent(RuntimeConfiguration.appGroupID, isDirectory: true)
                .appendingPathComponent("Finder Test", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if !NSWorkspace.shared.open(directory) {
                directoryError = "无法打开测试目录，请重试。"
            }
        } catch {
            directoryError = "无法创建测试目录：\(error.localizedDescription)"
        }
    }
}

#Preview {
    let appModel = AppModel(forPreview: true)
    VerifyStepView(launchAtLogin: .constant(true), verification: OnboardingVerification())
        .environment(appModel.appCoordinator)
        .environment(appModel.appCoordinator.configStore)
        .padding()
        .frame(width: 440)
}
