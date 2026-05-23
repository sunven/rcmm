import RCMMShared
import SwiftUI

struct BuiltInListRow: View {
    let item: BuiltInMenuItem
    let summary: FinderMenuEntrySummary
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onToggle: ((Bool) -> Void)?
    var position: Int?
    var total: Int?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundStyle(item.isEnabled ? .primary : .secondary)
                .frame(width: 28, height: 28)

            Text(item.displayName)
                .font(.callout)
                .foregroundStyle(item.isEnabled ? .primary : .secondary)
                .lineLimit(1)

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

            MenuRowReorderControls(onMoveUp: onMoveUp, onMoveDown: onMoveDown)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .controlSize(.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName)，系统功能，\(summary.statusText)")
        .ifLet(position) { view, pos in
            view.accessibilityValue("第 \(pos) 项，共 \(total ?? 1) 项")
        }
        .accessibilityHint("系统内置菜单功能")
        .ifLet(onMoveUp) { view, action in
            view.accessibilityAction(named: "上移", action)
        }
        .ifLet(onMoveDown) { view, action in
            view.accessibilityAction(named: "下移", action)
        }
    }
}
