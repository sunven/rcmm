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
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("验证 Finder 右键菜单")
                    .font(RCMMFont.pageTitle)
                    .foregroundStyle(RCMMColor.textPrimary)

                Text("在 Finder 中试一次，确认右键菜单可以打开应用。")
                    .font(RCMMFont.secondary)
                    .foregroundStyle(RCMMColor.textMuted)
            }

            statusLine

            if !verification.items(in: configStore).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(verification.items(in: configStore)) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: itemSymbol(for: item))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(itemColor(for: item))
                                    .frame(width: 14)

                                Text(item.name)
                                    .font(RCMMFont.secondary)
                                    .foregroundStyle(RCMMColor.textSecondary)
                            }

                            if verification.phase != .syncing, let issue = item.issue {
                                Text(issue)
                                    .font(RCMMFont.caption)
                                    .foregroundStyle(RCMMColor.warning)
                                    .textSelection(.enabled)
                                    .padding(.leading, 20)
                            }
                        }
                    }
                }
            }

            if verification.targets.isEmpty {
                Text("请返回上一步添加应用。")
                    .font(RCMMFont.caption)
                    .foregroundStyle(RCMMColor.textMuted)
            }

            RCMMPanel(title: "在 Finder 中验证") {
                instructionRow(1, "打开测试目录，在空白处右键")
                instructionRow(2, "点击菜单中列出的任意一个应用")
                instructionRow(3, "确认应用打开到测试目录")

                Text("如使用子菜单模式，请先展开 rcmm 菜单。")
                    .font(RCMMFont.caption)
                    .foregroundStyle(RCMMColor.textFaint)
            }

            HStack(spacing: 8) {
                Button("打开测试目录", action: openTestDirectory)
                    .buttonStyle(AppPrimaryButtonStyle())
                    .controlSize(.regular)
                    .disabled(!verification.isReady(in: configStore))

                if verification.phase != .syncing && !verification.isReady(in: configStore) {
                    retryButton
                }

                Spacer(minLength: 0)
            }

            if let directoryError {
                RCMMInlineMessage(directoryError, kind: .warning)
            }

            Toggle("已在 Finder 中成功打开应用", isOn: Binding(
                get: { verification.isConfirmed(in: configStore) },
                set: { verification.confirm($0, in: configStore) }
            ))
            .toggleStyle(.checkbox)
            .font(RCMMFont.secondary)
            .disabled(!verification.isReady(in: configStore))

            DisclosureGroup("菜单未出现", isExpanded: $showsRecovery) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("先关闭 Finder 右键菜单，重新打开；如仍未出现，请确认系统设置中已启用当前版本的 Finder 扩展。")
                        .font(RCMMFont.caption)
                        .foregroundStyle(RCMMColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        retryButton
                        Button("前往系统设置") {
                            PluginKitService.showExtensionManagement()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.top, 6)
                .padding(.leading, 2)
            }
            .font(RCMMFont.secondary)

            RCMMDivider()
                .padding(.top, 2)

            Toggle("开机自动启动", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .font(RCMMFont.secondary)
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if verification.phase == .syncing {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("正在同步所选应用…")
                    .font(RCMMFont.secondary)
                    .foregroundStyle(RCMMColor.textMuted)
            }
        } else if verification.isReady(in: configStore) {
            RCMMInlineMessage("配置已同步，请在 Finder 中验证", kind: .success)
        } else {
            RCMMInlineMessage("配置尚未同步成功", kind: .warning)
        }
    }

    private var retryButton: some View {
        Button("重新同步") {
            verification.retry(coordinator: appCoordinator)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(verification.phase == .syncing || verification.targets.isEmpty)
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

    private func itemSymbol(for item: OnboardingVerification.Item) -> String {
        if verification.phase == .syncing {
            return "arrow.triangle.2.circlepath"
        }
        return item.issue == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private func itemColor(for item: OnboardingVerification.Item) -> Color {
        if verification.phase == .syncing {
            return RCMMColor.textMuted
        }
        return item.issue == nil ? RCMMColor.success : RCMMColor.warning
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
        .padding(24)
        .frame(width: 460)
}
