import RCMMShared
import SwiftUI

struct BuiltInListRow: View {
    let item: BuiltInMenuItem
    let summary: FinderMenuEntrySummary
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onToggle: ((Bool) -> Void)?

    var body: some View {
        FinderMenuRow(
            title: item.displayName,
            subtitle: summary.subtitle,
            isEnabled: item.isEnabled,
            summary: summary,
            onToggle: onToggle
        ) {
            Image(systemName: item.iconName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(item.isEnabled ? RCMMColor.textSecondary : RCMMColor.textMuted)
        } trailing: {
            MenuRowActionsMenu(onMoveUp: onMoveUp, onMoveDown: onMoveDown)
        }
    }
}
