import AppKit
import RCMMShared

extension AppInfo {
    /// 运行时通过 NSWorkspace 获取应用图标（不持久化）
    /// 始终返回有效 NSImage（无自定义图标时返回通用应用图标）
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
}
