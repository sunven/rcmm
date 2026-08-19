import RCMMShared
import SwiftUI

struct BuiltInListRow: View {
    let item: BuiltInMenuItem
    let summary: FinderMenuEntrySummary
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onToggle: ((Bool) -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            FinderMenuRowIcon(isEnabled: item.isEnabled, isUnavailable: false) {
                Image(systemName: item.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(item.isEnabled ? .primary : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(item.isEnabled ? .primary : .secondary)
                    .lineLimit(1)

                if let subtitle = summary.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            FinderMenuStatusBadge(summary: summary)

            if let onToggle = onToggle {
                Toggle("", isOn: Binding(
                    get: { item.isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .help(item.isEnabled ? "停用此菜单项" : "启用此菜单项")
            }

            MenuRowActionsMenu(onMoveUp: onMoveUp, onMoveDown: onMoveDown)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .frame(minHeight: 40)
        .controlSize(.small)
        .contentShape(Rectangle())
    }
}
