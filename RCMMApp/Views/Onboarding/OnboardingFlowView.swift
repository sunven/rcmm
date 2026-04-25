import ServiceManagement
import SwiftUI
import os.log

struct OnboardingFlowView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep: OnboardingStep = .enableExtension
    @State private var isExtensionEnabled = false
    @State private var selectedAppIds: Set<UUID> = []
    @State private var launchAtLogin = true
    @State private var isCompleting = false
    @State private var registrationErrorMessage: String? = nil

    private let logger = Logger(subsystem: "com.sunven.rcmm", category: "onboarding")

    var body: some View {
        VStack(spacing: 0) {
            // 步骤指示器
            OnboardingStepIndicator(currentStep: currentStep)
                .padding(.top, 24)
                .padding(.bottom, 16)

            Divider()

            // 步骤内容
            Group {
                if isCompleting {
                    completionConfirmationView
                } else {
                    switch currentStep {
                    case .enableExtension:
                        EnableExtensionStepView(
                            isExtensionEnabled: $isExtensionEnabled,
                            onNext: { advanceToStep(.selectApps) }
                        )
                    case .selectApps:
                        SelectAppsStepView(selectedAppIds: $selectedAppIds)
                    case .verify:
                        VerifyStepView(launchAtLogin: $launchAtLogin)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Divider()

            // 底部导航
            HStack {
                if !isCompleting {
                    if currentStep == .enableExtension || currentStep == .selectApps {
                        Button("跳过") {
                            advanceToNextStep()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(currentStep == .enableExtension ? "跳过启用扩展步骤" : "跳过应用选择步骤")
                    } else if currentStep == .verify {
                        Button("跳过") {
                            completeOnboarding()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("跳过验证步骤并完成引导")
                    }
                }

                Spacer()

                if !isCompleting {
                    if currentStep == .selectApps {
                        Button("下一步") {
                            saveSelectedApps()
                            advanceToNextStep()
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .disabled(selectedAppIds.isEmpty)
                        .accessibilityLabel("前往下一步")
                    } else if currentStep == .verify {
                        Button("完成") {
                            completeOnboarding()
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .accessibilityLabel("完成引导设置")
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 480, height: 500)
        .onAppear {
            // 初始化时检测扩展状态，若已启用则跳到步骤 2
            if PluginKitService.isExtensionEnabled {
                isExtensionEnabled = true
                currentStep = .selectApps
            }
        }
    }

    // MARK: - 完成确认视图

    private var completionConfirmationView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("设置完成！")
                .font(.title2.bold())
                .accessibilityLabel("引导设置已完成")

            Text("现在可以在 Finder 中右键目录使用 rcmm 了")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let errorMessage = registrationErrorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    // MARK: - 导航

    private func advanceToStep(_ step: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
        }
    }

    private func advanceToNextStep() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        advanceToStep(nextStep)
    }

    private func saveSelectedApps() {
        let appsToAdd = appState.discoveredApps.filter { selectedAppIds.contains($0.id) }
        appState.addMenuItems(from: appsToAdd)
    }

    // MARK: - 引导完成

    private func completeOnboarding() {
        guard !isCompleting else { return }

        // 根据 Toggle 状态注册或取消开机自启
        if launchAtLogin {
            do {
                try SMAppService.mainApp.register()
            } catch {
                logger.error("开机自启注册失败: \(error.localizedDescription)")
                registrationErrorMessage = "开机自启设置失败，可在系统设置中手动开启"
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                // 首次安装时未注册属正常情况，记录 debug 日志
                logger.debug("开机自启取消注册（可能未注册）: \(error.localizedDescription)")
            }
        }

        appState.isOnboardingCompleted = true

        // 显示完成确认，短暂延迟后关闭窗口
        withAnimation(.easeInOut(duration: 0.3)) {
            isCompleting = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            appState.closeOnboarding()
        }
    }
}

#Preview {
    OnboardingFlowView()
        .environment(AppState())
}
