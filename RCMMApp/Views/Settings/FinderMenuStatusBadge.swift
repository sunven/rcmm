import RCMMShared
import SwiftUI

/// 行内状态标记。就绪、系统与停用保持安静；只有需要处理的同步中、警告和失败使用着色胶囊。
struct FinderMenuStatusBadge: View {
    let summary: FinderMenuEntrySummary

    private var isQuiet: Bool {
        switch summary.statusKind {
        case .ready, .disabled, .system:
            return true
        case .syncing, .failed, .unavailable, .partiallyAvailable, .warning:
            return false
        }
    }

    private var tint: Color {
        FinderMenuStatusStyle.color(for: summary.statusKind)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: FinderMenuStatusStyle.symbol(for: summary.statusKind))
                .font(.system(size: 9, weight: .bold))

            Text(summary.statusText)
                .font(RCMMFont.badge)
        }
        .foregroundStyle(isQuiet ? RCMMColor.textMuted : tint)
        .padding(.horizontal, isQuiet ? 3 : 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(isQuiet ? Color.clear : tint.opacity(0.12))
        )
        .fixedSize()
        .help(summary.statusDetail ?? summary.statusText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("状态：\(summary.statusText)")
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
            return RCMMColor.error
        case .partiallyAvailable, .warning:
            return RCMMColor.warning
        case .syncing:
            return RCMMColor.accentText
        case .ready:
            return RCMMColor.success
        case .disabled, .system:
            return RCMMColor.textMuted
        }
    }
}
