import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case enableExtension = 0
    case selectApps = 1
    case verify = 2

    var title: String {
        switch self {
        case .enableExtension: return "启用扩展"
        case .selectApps: return "选择应用"
        case .verify: return "验证菜单"
        }
    }
}

struct OnboardingStepIndicator: View {
    let currentStep: OnboardingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                if step.rawValue > 0 {
                    Rectangle()
                        .fill(step.rawValue <= currentStep.rawValue ? RCMMColor.accent : RCMMColor.line)
                        .frame(width: 32, height: 1)
                        .padding(.horizontal, 4)
                }

                stepView(for: step)
            }
        }
    }

    private func stepView(for step: OnboardingStep) -> some View {
        HStack(spacing: 6) {
            ZStack {
                switch step.rawValue {
                case ..<currentStep.rawValue:
                    Circle()
                        .fill(RCMMColor.accentSoft)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(RCMMColor.accentText)
                case currentStep.rawValue:
                    Circle()
                        .fill(RCMMColor.accent)
                    Text("\(step.rawValue + 1)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                default:
                    Circle()
                        .stroke(RCMMColor.line, lineWidth: 1)
                    Text("\(step.rawValue + 1)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(RCMMColor.textFaint)
                }
            }
            .frame(width: 20, height: 20)

            Text(step.title)
                .font(.system(size: 11, weight: step == currentStep ? .semibold : .regular))
                .foregroundStyle(step == currentStep ? RCMMColor.textPrimary : RCMMColor.textMuted)
        }
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
