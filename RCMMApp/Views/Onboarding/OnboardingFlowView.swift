import SwiftUI

struct OnboardingFlowView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep: OnboardingStep = .enableExtension
    @State private var isExtensionEnabled = false

    var body: some View {
        VStack(spacing: 0) {
            // 步骤指示器
            OnboardingStepIndicator(currentStep: currentStep)
                .padding(.top, 24)
                .padding(.bottom, 16)

            Divider()

            // 步骤内容
            Group {
                switch currentStep {
                case .enableExtension:
                    EnableExtensionStepView(
                        isExtensionEnabled: $isExtensionEnabled,
                        onNext: { advanceToStep(.selectApps) }
                    )
                case .selectApps:
                    selectAppsPlaceholder
                case .verify:
                    verifyPlaceholder
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Divider()

            // 底部导航
            HStack {
                if currentStep == .enableExtension {
                    Button("跳过") {
                        advanceToStep(.selectApps)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("跳过启用扩展步骤")
                }

                Spacer()

                if currentStep != .enableExtension {
                    Button("下一步") {
                        advanceToNextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("前往下一步")
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

    // MARK: - 占位视图（Story 3.2 / 3.3 实现）

    private var selectAppsPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("选择常用应用")
                .font(.title2.bold())
            Text("此步骤将在后续版本中实现。")
                .foregroundStyle(.secondary)
        }
    }

    private var verifyPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("验证完成")
                .font(.title2.bold())
            Text("此步骤将在后续版本中实现。")
                .foregroundStyle(.secondary)
        }
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
}

#Preview {
    OnboardingFlowView()
        .environment(AppState())
}
