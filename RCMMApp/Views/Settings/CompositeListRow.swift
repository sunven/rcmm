import RCMMShared
import SwiftUI

struct CompositeListRow: View {
    let config: CompositeMenuItemConfig
    let summary: FinderMenuEntrySummary
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onDelete: (() -> Void)?
    var onToggle: ((Bool) -> Void)?
    var position: Int?
    var total: Int?

    var body: some View {
        HStack(spacing: 10) {
            FinderMenuRowIcon(isEnabled: config.isEnabled, isUnavailable: summary.statusKind == .unavailable || summary.statusKind == .failed) {
                Image(systemName: config.iconName ?? "rectangle.stack.badge.play")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(config.isEnabled ? .primary : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(config.isEnabled ? .primary : .secondary)
                    .lineLimit(1)

                Text(summary.subtitle ?? "\(config.steps.count) 个步骤")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            FinderMenuStatusBadge(summary: summary)

            if let onToggle {
                Toggle("", isOn: Binding(
                    get: { config.isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .help(config.isEnabled ? "停用此组合命令" : "启用此组合命令")
            }

            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("删除此组合命令")
            }

            MenuRowReorderControls(onMoveUp: onMoveUp, onMoveDown: onMoveDown)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .frame(minHeight: 40)
        .controlSize(.small)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(config.name)，组合命令，\(summary.statusText)")
        .ifLet(position) { view, pos in
            view.accessibilityValue("第 \(pos) 项，共 \(total ?? 1) 项")
        }
        .ifLet(onMoveUp) { view, action in
            view.accessibilityAction(named: "上移", action)
        }
        .ifLet(onMoveDown) { view, action in
            view.accessibilityAction(named: "下移", action)
        }
        .ifLet(onDelete) { view, action in
            view.accessibilityAction(named: "删除", action)
        }
    }
}
