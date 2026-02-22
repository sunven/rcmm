import Foundation

public enum CommandMappingService: Sendable {
    /// 内置命令映射字典：bundleId → 命令模板
    /// 命令模板中使用 {path} 占位符表示目标目录
    /// 注意：{path} 不应被引号包裹，AppleScript 生成时使用 quoted form of 处理路径安全
    private static let builtInMappings: [String: String] = [
        "net.kovidgoyal.kitty": "/Applications/kitty.app/Contents/MacOS/kitty --single-instance --directory {path}",
        "org.alacritty": "/Applications/Alacritty.app/Contents/MacOS/alacritty --working-directory {path}",
        "com.github.wez.wezterm": "/Applications/WezTerm.app/Contents/MacOS/wezterm start --cwd {path}",
    ]

    /// 查找 bundleId 对应的内置命令模板
    /// - Returns: 命令模板字符串（含 {path} 占位符），无匹配则返回 nil
    public static func command(for bundleId: String?) -> String? {
        guard let bundleId else { return nil }
        return builtInMappings[bundleId]
    }
}
