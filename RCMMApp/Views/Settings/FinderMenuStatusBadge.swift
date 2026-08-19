import RCMMShared
import SwiftUI

struct FinderMenuStatusBadge: View {
    let summary: FinderMenuEntrySummary

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: FinderMenuStatusStyle.symbol(for: summary.statusKind))
                .font(.system(size: 9, weight: .bold))

            Text(summary.statusText)
                .font(.caption2.weight(.semibold))
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(FinderMenuStatusStyle.color(for: summary.statusKind))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(FinderMenuStatusStyle.color(for: summary.statusKind).opacity(0.12))
        )
    }
}

enum FinderMenuStatusStyle {
    static func symbol(for kind: FinderMenuEntryStatusKind) -> String {
        switch kind {
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
        case .system:
            return "gearshape.fill"
        }
    }

    static func color(for kind: FinderMenuEntryStatusKind) -> Color {
        switch kind {
        case .failed, .unavailable:
            return .red
        case .partiallyAvailable, .warning:
            return .orange
        case .syncing:
            return .blue
        case .ready:
            return .green
        case .disabled, .system:
            return .secondary
        }
    }
}
