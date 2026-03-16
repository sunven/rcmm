import RCMMShared
import SwiftUI

struct BuiltInListRow: View {
    let item: BuiltInMenuItem
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onToggle: ((Bool) -> Void)?
    var position: Int?
    var total: Int?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(item.isEnabled ? .primary : .secondary)
                .frame(width: 32, height: 32)

            Text(item.displayName)
                .font(.body)
                .foregroundStyle(item.isEnabled ? .primary : .secondary)

            Text("系统")
                .font(.caption)
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                )

            Spacer()

            if !item.isEnabled {
                Text("已停用")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let onToggle = onToggle {
                Toggle("", isOn: Binding(
                    get: { item.isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .help(item.isEnabled ? "停用此菜单项" : "启用此菜单项")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.displayName)，系统功能")
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
