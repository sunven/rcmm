import ServiceManagement
import SwiftUI
import os.log

struct OnboardingFlowView: View {
    @Environment(ApplicationDiscoveryCoordinator.self) private var applicationDiscovery
    @Environment(AppFlowCoordinator.self) private var appFlowCoordinator
    @Environment(AppCoordinator.self) private var appCoordinator
    @State private var verification = OnboardingVerification()
    @State private var didPreselectApps = false
    @State private var currentStep: OnboardingStep = .enableExtension
    @State private var isExtensionEnabled = false
    @State private var selectedAppIds: Set<UUID> = []
    @State private var launchAtLogin = true
    @State private var autoAdvanceWhenExtensionEnabled = true
    @State private var isCompleting = false
    @State private var registrationErrorMessage: String? = nil

    private let logger = Logger(subsystem: "com.sunven.rcmm", category: "onboarding")

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepIndicator(currentStep: currentStep)
                .padding(.top, 18)
                .padding(.bottom, 14)

            RCMMDivider()

            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 16)

            RCMMDivider()

            bottomBar
        }
        .frame(width: 480, height: 500)
        .background(RCMMColor.window)
        .onDisappear {
            verification.leave()
        }
        .onChange(of: verification.currentEntries(in: appCoordinator.configStore)) { _, _ in
            verification.confirm(false, in: appCoordinator.configStore)
        }
        .onChange(of: verification.isReady(in: appCoordinator.configStore)) { _, ready in
            if !ready { verification.confirm(false, in: appCoordinator.configStore) }
        }
        .onAppear {
            // 初始化时检测扩展状态，若已启用则跳到步骤 2
            if PluginKitService.isExtensionEnabled {
                isExtensionEnabled = true
                currentStep = .selectApps
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            if !isCompleting {
                Button("跳过") {
                    skipOnboarding()
                }
                .buttonStyle(.plain)
                .font(RCMMFont.caption)
                .foregroundStyle(RCMMColor.textMuted)
            }

            Spacer()

            if !isCompleting {
                if canGoBack {
                    Button("上一步") {
                        returnToPreviousStep()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                if currentStep == .enableExtension {
                    Button("下一步") {
                        advanceToNextStep()
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .controlSize(.regular)
                    .disabled(!isExtensionEnabled)
                } else if currentStep == .selectApps {
                    Button("下一步") {
                        advanceToNextStep()
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .controlSize(.regular)
                    .disabled(!canContinueFromSelection)
                } else if currentStep == .verify {
                    Button("完成") {
                        completeOnboarding()
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .controlSize(.regular)
                    .disabled(!verification.isConfirmed(in: appCoordinator.configStore))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(RCMMColor.surfaceSoft)
    }

    @ViewBuilder
    private var stepContent: some View {
        if isCompleting {
            completionConfirmationView
        } else {
            switch currentStep {
            case .enableExtension:
                EnableExtensionStepView(
                    isExtensionEnabled: $isExtensionEnabled,
                    autoAdvanceWhenEnabled: autoAdvanceWhenExtensionEnabled,
                    onNext: { advanceFromExtensionStep() }
                )
            case .selectApps:
                SelectAppsStepView(selectedAppIds: $selectedAppIds, didPreselectApps: $didPreselectApps)
            case .verify:
                VerifyStepView(launchAtLogin: $launchAtLogin, verification: verification)
            }
        }
    }

    // MARK: - 完成确认视图

    private var completionConfirmationView: some View {
        VStack(spacing: 10) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(RCMMColor.success)

            Text("设置完成")
                .font(RCMMFont.pageTitle)
                .foregroundStyle(RCMMColor.textPrimary)

            Text("在 Finder 中右键目录即可使用 rcmm")
                .font(RCMMFont.secondary)
                .foregroundStyle(RCMMColor.textMuted)
                .multilineTextAlignment(.center)

            if let errorMessage = registrationErrorMessage {
                RCMMInlineMessage(errorMessage, kind: .warning)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    // MARK: - 导航

    private var canContinueFromSelection: Bool {
        !applicationDiscovery.isScanning && (
            applicationDiscovery.apps.contains { selectedAppIds.contains($0.id) }
                || !verification.targets.isEmpty
                || OnboardingVerification.existingApplication(in: appCoordinator.configStore.menuEntries) != nil
        )
    }

    private var canGoBack: Bool {
        currentStep.rawValue > OnboardingStep.enableExtension.rawValue
    }

    private func advanceToStep(_ step: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentStep = step
        }
    }

    private func advanceFromExtensionStep() {
        autoAdvanceWhenExtensionEnabled = true
        advanceToStep(.selectApps)
    }

    private func advanceToNextStep() {
        if currentStep == .selectApps {
            guard canContinueFromSelection else { return }
            let apps = applicationDiscovery.apps.filter { selectedAppIds.contains($0.id) }
            verification.prepare(apps: apps, coordinator: appCoordinator)
            selectedAppIds.removeAll()
        }
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        if currentStep == .enableExtension {
            autoAdvanceWhenExtensionEnabled = true
        }
        advanceToStep(nextStep)
    }

    private func returnToPreviousStep() {
        verification.leave()
        guard let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        if previousStep == .enableExtension {
            autoAdvanceWhenExtensionEnabled = false
        }
        advanceToStep(previousStep)
    }

    // MARK: - 引导完成

    private func skipOnboarding() {
        guard !isCompleting else { return }
        verification.leave()
        appFlowCoordinator.completeOnboarding()
    }

    private func completeOnboarding() {
        guard !isCompleting, verification.isConfirmed(in: appCoordinator.configStore) else { return }

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

        // 显示完成确认，短暂延迟后关闭窗口
        withAnimation(.easeInOut(duration: 0.25)) {
            isCompleting = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            appFlowCoordinator.completeOnboarding()
        }
    }
}

#Preview {
    let appModel = AppModel(forPreview: true)

    OnboardingFlowView()
        .environment(appModel.appFlowCoordinator)
        .environment(appModel.applicationDiscoveryCoordinator)
        .environment(appModel.appCoordinator)
        .environment(appModel.appCoordinator.configStore)
}
