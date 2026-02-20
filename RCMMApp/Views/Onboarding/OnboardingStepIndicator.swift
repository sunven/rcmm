import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case enableExtension = 0
    case selectApps = 1
    case verify = 2

    var title: String {
        switch self {
        case .enableExtension: return "启用扩展"
        case .selectApps: return "选择应用"
        case .verify: return "验证完成"
        }
    }
}

struct OnboardingStepIndicator: View {
    let currentStep: OnboardingStep

    var body: some View {
        HStack(spacing: 0) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                if step.rawValue > 0 {
                    connectorLine(before: step)
                }
                stepCircle(for: step)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("步骤 \(currentStep.rawValue + 1)，共 3 步，当前：\(currentStep.title)")
    }

    @ViewBuilder
    private func stepCircle(for step: OnboardingStep) -> some View {
        VStack(spacing: 6) {
            ZStack {
                if step.rawValue < currentStep.rawValue {
                    // 已完成
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else if step == currentStep {
                    // 当前
                    Image(systemName: "circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                } else {
                    // 待完成
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(step.title)
                .font(.caption)
                .foregroundStyle(step == currentStep ? .primary : .secondary)
        }
    }

    @ViewBuilder
    private func connectorLine(before step: OnboardingStep) -> some View {
        Rectangle()
            .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: 60)
            .padding(.horizontal, 8)
            .padding(.bottom, 20)
    }
}

#Preview("Step 1") {
    OnboardingStepIndicator(currentStep: .enableExtension)
        .padding()
}

#Preview("Step 2") {
    OnboardingStepIndicator(currentStep: .selectApps)
        .padding()
}

#Preview("Step 3") {
    OnboardingStepIndicator(currentStep: .verify)
        .padding()
}
