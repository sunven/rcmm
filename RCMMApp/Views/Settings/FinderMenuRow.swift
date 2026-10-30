import RCMMShared
import SwiftUI

/// Finder 菜单列表的统一行布局：图标、标题、副标题、状态、开关与行尾操作。
struct FinderMenuRow<Icon: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let isEnabled: Bool
    let isUnavailable: Bool
    let hasUnsavedChanges: Bool
    let summary: FinderMenuEntrySummary
    let onToggle: ((Bool) -> Void)?
    @ViewBuilder let icon: Icon
    @ViewBuilder let trailing: Trailing

    init(
        title: String,
        subtitle: String?,
        isEnabled: Bool,
        isUnavailable: Bool = false,
        hasUnsavedChanges: Bool = false,
        summary: FinderMenuEntrySummary,
        onToggle: ((Bool) -> Void)? = nil,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isEnabled = isEnabled
        self.isUnavailable = isUnavailable
        self.hasUnsavedChanges = hasUnsavedChanges
        self.summary = summary
        self.onToggle = onToggle
        self.icon = icon()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: 26, height: 26)
                .saturation(isUnavailable ? 0 : (isEnabled ? 1 : 0.25))
                .opacity(isUnavailable ? 0.45 : (isEnabled ? 1 : 0.6))
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(RCMMFont.rowTitle)
                        .foregroundStyle(isEnabled ? RCMMColor.textPrimary : RCMMColor.textMuted)
                        .lineLimit(1)

                    if hasUnsavedChanges {
                        Circle()
                            .fill(RCMMColor.accent)
                            .frame(width: 5, height: 5)
                            .help("有未保存的修改")
                    }
                }

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(RCMMFont.caption)
                        .foregroundStyle(RCMMColor.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 8)

            FinderMenuStatusBadge(summary: summary)

            if let onToggle {
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .accessibilityLabel(isEnabled ? "停用 \(title)" : "启用 \(title)")
                .help(isEnabled ? "停用此菜单项" : "启用此菜单项")
            }

            trailing
        }
        .frame(minHeight: 42)
        .contentShape(Rectangle())
    }
}
