import Foundation

public enum FinderMenuIconPolicy: Sendable {
    public static let applicationPlaceholderSymbolName = "app"
    public static let currentDirectorySymbolName = "terminal"

    public static func shouldPreloadApplicationIcon(for config: MenuItemConfig) -> Bool {
        guard config.executionMode != .currentDirectory else {
            return false
        }
        return !config.appPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func placeholderSymbolName(for config: MenuItemConfig) -> String {
        config.executionMode == .currentDirectory
            ? currentDirectorySymbolName
            : applicationPlaceholderSymbolName
    }
}
