import RCMMShared
import SwiftUI

struct FinderMenuStatusBadge: View {
    let summary: FinderMenuEntrySummary

    var body: some View {
        Text(summary.statusText)
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

    private var color: Color {
        switch summary.statusKind {
        case .failed, .unavailable:
            return .red
        case .disabled, .partiallyAvailable, .warning:
            return .orange
        case .syncing:
            return .blue
        case .ready, .command, .system:
            return .secondary
        }
    }
}
