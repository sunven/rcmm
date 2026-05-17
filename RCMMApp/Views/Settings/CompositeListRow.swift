import RCMMShared
import SwiftUI

struct CompositeListRow: View {
    let config: CompositeMenuItemConfig
    let publishState: ScriptPublishState?
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onDelete: (() -> Void)?
    var onToggle: ((Bool) -> Void)?
    var position: Int?
    var total: Int?

    @State private var isHovered = false

    private var validation: CompositeValidationResult {
        CompositeMenuItemValidator.validate(config)
    }

    private var status: (text: String, color: Color) {
        if !config.isEnabled {
            return ("已停用", .orange)
        }
        if validation.hasErrors && validation.executableStepIDs.isEmpty {
            return ("不可用", .red)
        }
        if validation.hasErrors {
            return ("部分可用", .orange)
        }
        if validation.hasWarnings {
            return ("有警告", .yellow)
        }
        guard let publishState else {
            return ("同步中", .secondary)
        }
        if publishState.fingerprint != validation.fingerprint {
            return ("同步中", .secondary)
        }
        switch publishState.status {
        case .current:
            return ("就绪", .secondary)
        case .compileFailed:
            return ("同步失败", .red)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: config.iconName ?? "rectangle.stack.badge.play")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundStyle(config.isEnabled ? .primary : .secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.callout)
                    .foregroundStyle(config.isEnabled ? .primary : .secondary)
                    .lineLimit(1)

                Text("\(config.steps.count) 个步骤")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(status.text)
                .font(.caption2.weight(.medium))
                .foregroundStyle(status.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(status.color.opacity(0.12))
                )

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
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
        )
        .controlSize(.small)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(config.name)，组合命令，\(status.text)")
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
