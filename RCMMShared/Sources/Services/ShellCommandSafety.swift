import Foundation

public enum ShellCommandSafety: Sendable {
    public static func dangerousPatterns(in command: String) -> [String] {
        let normalized = command
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        var matches: [String] = []
        if normalized.contains("rm -rf") {
            matches.append("rm -rf")
        }
        if normalized.contains("sudo") {
            matches.append("sudo")
        }
        if normalized.range(
            of: #"curl\b.*\|\s*(sh|bash)\b"#,
            options: .regularExpression
        ) != nil {
            matches.append("curl | sh")
        }
        if normalized.contains("chmod -r") {
            matches.append("chmod -R")
        }
        if normalized.contains("launchctl") {
            matches.append("launchctl")
        }
        if normalized.contains("osascript -e") {
            matches.append("osascript -e")
        }
        return matches
    }
}
