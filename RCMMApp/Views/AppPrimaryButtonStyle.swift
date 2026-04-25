import AppKit
import SwiftUI

struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.9))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .opacity(isEnabled ? 1 : 0.72)
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
            return 6
        case .small:
            return 7
        case .regular:
            return 9
        case .large:
            return 10
        @unknown default:
            return 9
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        let accentColor = Color(nsColor: .controlAccentColor)

        guard isEnabled else {
            return accentColor.opacity(0.42)
        }

        return isPressed ? accentColor.opacity(0.82) : accentColor
    }
}
