import AppKit
import RCMMShared
import SwiftUI

struct AppListRow: View {
    let menuItem: MenuItemConfig
    let summary: FinderMenuEntrySummary
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onDelete: (() -> Void)?
    var onToggle: ((Bool) -> Void)?

    private var isShellCommand: Bool {
        menuItem.executionMode == .currentDirectory
    }

    var body: some View {
        HStack(spacing: 10) {
            FinderMenuRowIcon(isEnabled: menuItem.isEnabled, isUnavailable: isUnavailable) {
                menuIcon
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(menuItem.appName)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(menuItem.isEnabled ? .primary : .secondary)
                    .lineLimit(1)

                if let subtitle = summary.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 8)

            FinderMenuStatusBadge(summary: summary)

            if let onToggle = onToggle {
                Toggle("", isOn: Binding(
                    get: { menuItem.isEnabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .help(menuItem.isEnabled ? "停用此菜单项" : "启用此菜单项")
            }

            MenuRowActionsMenu(
                onMoveUp: onMoveUp,
                onMoveDown: onMoveDown,
                onDelete: onDelete,
                deleteLabel: "删除菜单项"
            )
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .frame(minHeight: 40)
        .controlSize(.small)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var menuIcon: some View {
        if isShellCommand {
            Image(systemName: "terminal")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
        } else {
            Image(nsImage: NSWorkspace.shared.icon(forFile: menuItem.appPath))
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }

    private var isUnavailable: Bool {
        summary.statusKind == .unavailable || summary.statusKind == .failed
    }

}

struct FinderMenuRowIcon<Content: View>: View {
    let isEnabled: Bool
    let isUnavailable: Bool
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(width: 20, height: 20)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.primary.opacity(0.06))
            )
            .saturation(isUnavailable ? 0 : (isEnabled ? 1 : 0.3))
            .opacity(isUnavailable ? 0.42 : (isEnabled ? 1 : 0.56))
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
        summary: FinderMenuEntrySummary(
            id: UUID().uuidString,
            title: "Terminal",
            subtitle: "/System/Applications/Utilities/Terminal.app",
            kind: .customApp,
            typeLabel: "应用",
            symbolName: nil,
            appPath: "/System/Applications/Utilities/Terminal.app",
            isEnabled: true,
            position: 1,
            total: 3,
            statusKind: .ready,
            statusText: "就绪",
            statusDetail: nil,
            allowsDelete: true
        ),
        onToggle: { _ in }
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
        summary: FinderMenuEntrySummary(
            id: UUID().uuidString,
            title: "iTerm",
            subtitle: "/Applications/iTerm.app",
            kind: .customApp,
            typeLabel: "应用",
            symbolName: nil,
            appPath: "/Applications/iTerm.app",
            isEnabled: false,
            position: 2,
            total: 3,
            statusKind: .disabled,
            statusText: "已停用",
            statusDetail: nil,
            allowsDelete: true
        ),
        onToggle: { _ in }
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
        summary: FinderMenuEntrySummary(
            id: UUID().uuidString,
            title: "不存在的应用",
            subtitle: "/Applications/NonExistent.app",
            kind: .customApp,
            typeLabel: "应用",
            symbolName: nil,
            appPath: "/Applications/NonExistent.app",
            isEnabled: true,
            position: 3,
            total: 3,
            statusKind: .unavailable,
            statusText: "未找到",
            statusDetail: nil,
            allowsDelete: true
        ),
        onToggle: { _ in }
    )
    .padding()
}
