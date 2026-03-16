import AppKit
import RCMMShared
import SwiftUI

struct AppListRow: View {
    let menuItem: MenuItemConfig
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onDelete: (() -> Void)?
    var onToggle: ((Bool) -> Void)?
    var position: Int?
    var total: Int?

    @State private var isHovered = false

    private var appExists: Bool {
        FileManager.default.fileExists(atPath: menuItem.appPath)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: menuItem.appPath))
                .resizable()
                .frame(width: 32, height: 32)
                .saturation(appExists ? (menuItem.isEnabled ? 1 : 0.3) : 0)
                .opacity(appExists ? (menuItem.isEnabled ? 1 : 0.5) : 0.4)
            Text(menuItem.appName)
                .font(.body)
                .foregroundStyle(menuItem.isEnabled ? .primary : .secondary)
            Spacer()

            if !menuItem.isEnabled {
                Text("已停用")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text(appExists ? "就绪" : "未找到")
                    .font(.caption)
                    .foregroundStyle(appExists ? Color.secondary : Color.red)
            }

            if let onToggle = onToggle {
                Toggle("", isOn: Binding(
                    get: { menuItem.isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .help(menuItem.isEnabled ? "停用此菜单项" : "启用此菜单项")
            }

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("删除此菜单项")
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
        .accessibilityLabel(menuItem.appName)
        .ifLet(position) { view, pos in
            view.accessibilityValue("第 \(pos) 项，共 \(total ?? 1) 项")
        }
        .accessibilityHint(appExists ? "右键菜单应用项" : "应用未找到，请检查是否已安装")
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

#Preview("启用状态") {
    AppListRow(
        menuItem: MenuItemConfig(
            appName: "Terminal",
            bundleId: "com.apple.Terminal",
            appPath: "/System/Applications/Utilities/Terminal.app",
            isEnabled: true
        ),
        onToggle: { _ in },
        position: 1,
        total: 3
    )
    .padding()
}

#Preview("禁用状态") {
    AppListRow(
        menuItem: MenuItemConfig(
            appName: "iTerm",
            appPath: "/Applications/iTerm.app",
            isEnabled: false
        ),
        onToggle: { _ in },
        position: 2,
        total: 3
    )
    .padding()
}

#Preview("应用未找到") {
    AppListRow(
        menuItem: MenuItemConfig(
            appName: "不存在的应用",
            appPath: "/Applications/NonExistent.app",
            isEnabled: true
        ),
        onToggle: { _ in },
        position: 3,
        total: 3
    )
    .padding()
}

extension View {
    @ViewBuilder
    func ifLet<T, V: View>(_ value: T?, transform: (Self, T) -> V) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}
