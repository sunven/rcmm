import AppKit
import RCMMShared
import SwiftUI

struct AppListRow: View {
    let menuItem: MenuItemConfig
    var isDefault: Bool = false
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?
    var position: Int?
    var total: Int?

    private var appExists: Bool {
        FileManager.default.fileExists(atPath: menuItem.appPath)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: menuItem.appPath))
                .resizable()
                .frame(width: 32, height: 32)
            Text(menuItem.appName)
                .font(.body)
            if isDefault {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                Text("默认")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(appExists ? "就绪" : "未找到")
                .font(.caption)
                .foregroundStyle(appExists ? Color.secondary : Color.red)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isDefault ? "\(menuItem.appName)，默认项" : menuItem.appName)
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
    }
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
