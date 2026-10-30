import AppKit
import RCMMShared
import SwiftUI

struct AppListRow: View {
    let menuItem: MenuItemConfig
    let summary: FinderMenuEntrySummary
    var hasUnsavedChanges = false
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var onDelete: (() -> Void)?
    var onToggle: ((Bool) -> Void)?

    private var isShellCommand: Bool {
        menuItem.executionMode == .currentDirectory
    }

    private var isUnavailable: Bool {
        summary.statusKind == .unavailable || summary.statusKind == .failed
    }

    var body: some View {
        FinderMenuRow(
            title: menuItem.appName,
            subtitle: summary.subtitle,
            isEnabled: menuItem.isEnabled,
            isUnavailable: isUnavailable,
            hasUnsavedChanges: hasUnsavedChanges,
            summary: summary,
            onToggle: onToggle
        ) {
            menuIcon
        } trailing: {
            MenuRowActionsMenu(
                onMoveUp: onMoveUp,
                onMoveDown: onMoveDown,
                onDelete: onDelete,
                deleteLabel: "删除菜单项"
            )
        }
    }

    @ViewBuilder
    private var menuIcon: some View {
        if isShellCommand {
            Image(systemName: "terminal")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(RCMMColor.textMuted)
        } else {
            Image(nsImage: NSWorkspace.shared.icon(forFile: menuItem.appPath))
                .resizable()
                .aspectRatio(contentMode: .fit)
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
