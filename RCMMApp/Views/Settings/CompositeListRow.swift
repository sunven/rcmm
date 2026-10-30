import RCMMShared
import SwiftUI

struct CompositeListRow: View {
    let config: CompositeMenuItemConfig
    let summary: FinderMenuEntrySummary
    var hasUnsavedChanges = false
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onDelete: (() -> Void)?
    var onToggle: ((Bool) -> Void)?

    var body: some View {
        FinderMenuRow(
            title: config.name,
            subtitle: summary.subtitle ?? "\(config.steps.count) 个步骤",
            isEnabled: config.isEnabled,
            isUnavailable: summary.statusKind == .unavailable || summary.statusKind == .failed,
            hasUnsavedChanges: hasUnsavedChanges,
            summary: summary,
            onToggle: onToggle
        ) {
            Image(systemName: config.iconName ?? "rectangle.stack.badge.play")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(config.isEnabled ? RCMMColor.textSecondary : RCMMColor.textMuted)
        } trailing: {
            MenuRowActionsMenu(
                onMoveUp: onMoveUp,
                onMoveDown: onMoveDown,
                onDelete: onDelete,
                deleteLabel: "删除组合命令"
            )
        }
    }
}
