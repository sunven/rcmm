import AppKit
import SwiftUI

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isEnabled ? Color.white : RCMMColor.textMuted)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private var horizontalPadding: CGFloat {
        switch controlSize {
        case .mini:
            return 8
        case .small:
            return 10
        case .regular:
            return 14
        case .large:
            return 18
        @unknown default:
            return 14
        }
    }

    private var verticalPadding: CGFloat {
        switch controlSize {
        case .mini:
            return 4
        case .small:
            return 5
        case .regular:
            return 7
        case .large:
            return 9
        @unknown default:
            return 7
        }
    }

    private var cornerRadius: CGFloat {
        switch controlSize {
        case .mini:
            return 5
        case .small:
            return 6
        case .regular:
            return 7
        case .large:
            return 8
        @unknown default:
            return 7
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return Color.primary.opacity(0.08)
        }

        return isPressed ? RCMMColor.accent.opacity(0.82) : RCMMColor.accent
    }
}
