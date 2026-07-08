import RCMMShared
import SwiftUI

struct FinderMenuStatusBadge: View {
    let summary: FinderMenuEntrySummary

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.system(size: 9, weight: .bold))

            Text(summary.statusText)
                .font(.caption2.weight(.semibold))
        }
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
            .accessibilityLabel("状态：\(summary.statusText)")
    }

    private var symbolName: String {
        switch summary.statusKind {
        case .ready:
            return "checkmark.circle.fill"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .failed, .unavailable:
            return "exclamationmark.triangle.fill"
        case .partiallyAvailable, .warning:
            return "exclamationmark.circle.fill"
        case .disabled:
            return "pause.circle.fill"
        case .command:
            return "terminal.fill"
        case .system:
            return "gearshape.fill"
        }
    }

    private var color: Color {
        switch summary.statusKind {
        case .failed, .unavailable:
            return .red
        case .partiallyAvailable, .warning:
            return .orange
        case .syncing:
            return .blue
        case .ready:
            return .green
        case .command:
            return .blue
        case .disabled, .system:
            return .secondary
        }
    }
}
