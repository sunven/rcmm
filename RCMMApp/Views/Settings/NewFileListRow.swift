import RCMMShared
import SwiftUI

struct NewFileListRow: View {
    let config: NewFileMenuConfig
    let summary: FinderMenuEntrySummary
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onDelete: (() -> Void)?
    var onToggle: ((Bool) -> Void)?

    var body: some View {
        FinderMenuRow(
            title: config.name,
            subtitle: summary.subtitle ?? "\(config.templates.count) 个模板",
            isEnabled: config.isEnabled,
            isUnavailable: summary.statusKind == .unavailable || summary.statusKind == .failed,
            summary: summary,
            onToggle: onToggle
        ) {
            Image(systemName: config.iconName ?? "document.badge.plus")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(config.isEnabled ? RCMMColor.textSecondary : RCMMColor.textMuted)
        } trailing: {
            MenuRowActionsMenu(
                onMoveUp: onMoveUp,
                onMoveDown: onMoveDown,
                onDelete: onDelete,
                deleteLabel: "删除新建菜单"
            )
        }
    }
}
