import AppKit
import RCMMShared
import SwiftUI

struct AppListRow: View {
    let menuItem: MenuItemConfig

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
            Spacer()
            Text(appExists ? "就绪" : "未找到")
                .font(.caption)
                .foregroundStyle(appExists ? Color.secondary : Color.red)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(menuItem.appName)
        .accessibilityHint(appExists ? "右键菜单应用项" : "应用未找到，请检查是否已安装")
    }
}
