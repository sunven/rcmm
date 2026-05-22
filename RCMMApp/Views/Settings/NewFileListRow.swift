import RCMMShared
import SwiftUI

struct NewFileListRow: View {
    let config: NewFileMenuConfig
    let publishStates: [String: ScriptPublishState]
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onDelete: (() -> Void)?
    var onToggle: ((Bool) -> Void)?
    var position: Int?
    var total: Int?

    @State private var isHovered = false

    private var validation: NewFileValidationResult {
        NewFileMenuValidator.validate(config)
    }

    private var currentTemplateCount: Int {
        FinderMenuPresenter
            .visibleNewFileTemplates(for: config, publishStates: publishStates)
            .count
    }

    private var status: (text: String, color: Color) {
        if !config.isEnabled {
            return ("已停用", .orange)
        }
        if validation.hasErrors && validation.executableTemplateIDs.isEmpty {
            return ("不可用", .red)
        }
        if validation.hasErrors {
            return ("部分可用", .orange)
        }
        if validation.hasWarnings {
            return ("有警告", .yellow)
        }
        if currentTemplateCount < validation.executableTemplateIDs.count {
            return ("同步中", .secondary)
        }
        return ("就绪", .secondary)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: config.iconName ?? "document.badge.plus")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 17, height: 17)
                .foregroundStyle(config.isEnabled ? .primary : .secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.callout)
                    .foregroundStyle(config.isEnabled ? .primary : .secondary)
                    .lineLimit(1)

                Text("\(config.templates.count) 个模板")
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
                .help(config.isEnabled ? "停用此新建菜单" : "启用此新建菜单")
            }

            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("删除此新建菜单")
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
        .accessibilityLabel("\(config.name)，新建文件菜单，\(status.text)")
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
