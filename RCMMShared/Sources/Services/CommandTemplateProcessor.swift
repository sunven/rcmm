import Foundation

/// 命令模板处理器：处理自定义命令中的 {app} 和 {path} 占位符，生成 AppleScript 命令字符串
public enum CommandTemplateProcessor: Sendable {
    /// 将命令模板转换为 AppleScript do shell script 命令
    ///
    /// - `{app}` 在编译时替换为 appPath
    /// - `{path}` 在运行时通过 AppleScript 的 `quoted form of thePath` 替换
    ///
    /// - Returns: AppleScript 命令字符串（如 `do shell script "..." & quoted form of thePath`）
    public static func buildAppleScriptCommand(template: String, appPath: String) -> String {
        // Step 1: 替换 {app} 为实际应用路径
        let processedCommand = template.replacingOccurrences(of: "{app}", with: appPath)

        // Step 2: 处理 {path} 占位符
        if processedCommand.contains("{path}") {
            let parts = processedCommand.components(separatedBy: "{path}")
            let prefix = escapeForAppleScript(parts[0])
            let suffix = parts.count > 1 ? escapeForAppleScript(parts[1]) : ""
            if suffix.isEmpty {
                return "do shell script \"\(prefix)\" & quoted form of thePath"
            } else {
                return "do shell script \"\(prefix)\" & quoted form of thePath & \"\(suffix)\""
            }
        } else {
            // 无 {path} — 静态命令
            let escapedCommand = escapeForAppleScript(processedCommand)
            return "do shell script \"\(escapedCommand)\""
        }
    }

    /// 转义字符串以安全嵌入 AppleScript 双引号字符串
    public static func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
