import Foundation

/// 命令模板处理器：处理自定义命令中的 {app}、{bundle} 和 {path} 占位符，生成 AppleScript 命令字符串
public enum CommandTemplateProcessor: Sendable {
    /// 将命令模板转换为 AppleScript do shell script 命令
    ///
    /// - `{app}` 在编译时替换为 appPath
    /// - `{bundle}` 在编译时替换为 bundleId
    /// - `{path}` 在运行时通过 AppleScript 的 `quoted form of thePath` 替换
    ///
    /// - Returns: AppleScript 命令字符串（如 `do shell script "..." & quoted form of thePath`）
    public static func buildAppleScriptCommand(
        template: String,
        appPath: String,
        bundleId: String? = nil,
        quoteAppPlaceholder: Bool = false
    ) -> String {
        if quoteAppPlaceholder {
            return buildAppleScriptCommandWithQuotedPlaceholders(
                template: template,
                appPath: appPath,
                bundleId: bundleId
            )
        }

        // Step 1: 替换静态占位符
        let processedCommand = template
            .replacingOccurrences(of: "{app}", with: appPath)
            .replacingOccurrences(of: "{bundle}", with: bundleId ?? "")

        // Step 2: 处理 {path} 占位符
        if processedCommand.contains("{path}") {
            let parts = processedCommand.components(separatedBy: "{path}")
            var expressionParts: [String] = []

            for index in parts.indices {
                if !parts[index].isEmpty {
                    expressionParts.append("\"\(escapeForAppleScript(parts[index]))\"")
                }

                if index < parts.count - 1 {
                    expressionParts.append("quoted form of thePath")
                }
            }

            return "do shell script \(expressionParts.joined(separator: " & "))"
        } else {
            // 无 {path} — 静态命令
            let escapedCommand = escapeForAppleScript(processedCommand)
            return "do shell script \"\(escapedCommand)\""
        }
    }

    private static func buildAppleScriptCommandWithQuotedPlaceholders(
        template: String,
        appPath: String,
        bundleId: String?
    ) -> String {
        var expressionParts: [String] = []
        var cursor = template.startIndex

        while cursor < template.endIndex {
            let remaining = template[cursor...]
            let candidates = CommandPlaceholder.allCases.compactMap { placeholder -> (CommandPlaceholder, Range<String.Index>)? in
                guard let range = remaining.range(of: placeholder.rawValue) else { return nil }
                return (placeholder, range)
            }
            let nextPlaceholder = candidates.min { lhs, rhs in
                lhs.1.lowerBound < rhs.1.lowerBound
            }

            guard let (placeholder, placeholderRange) = nextPlaceholder else {
                appendLiteral(String(template[cursor...]), to: &expressionParts)
                break
            }

            appendLiteral(String(template[cursor..<placeholderRange.lowerBound]), to: &expressionParts)

            switch placeholder {
            case .app:
                expressionParts.append("quoted form of \"\(escapeForAppleScript(appPath))\"")
            case .bundle:
                expressionParts.append("quoted form of \"\(escapeForAppleScript(bundleId ?? ""))\"")
            case .path:
                expressionParts.append("quoted form of thePath")
            }
            cursor = placeholderRange.upperBound
        }

        if expressionParts.isEmpty {
            return "do shell script \"\""
        }
        return "do shell script \(expressionParts.joined(separator: " & "))"
    }

    private static func appendLiteral(_ literal: String, to expressionParts: inout [String]) {
        guard !literal.isEmpty else { return }
        expressionParts.append("\"\(escapeForAppleScript(literal))\"")
    }

    private enum CommandPlaceholder: String, CaseIterable {
        case app = "{app}"
        case bundle = "{bundle}"
        case path = "{path}"
    }

    /// 转义字符串以安全嵌入 AppleScript 双引号字符串
    public static func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
