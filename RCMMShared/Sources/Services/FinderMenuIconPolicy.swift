import Foundation

public enum FinderMenuIconPolicy: Sendable {
    public static let applicationPlaceholderSymbolName = "app"
    public static let currentDirectorySymbolName = "terminal"

    public static func placeholderSymbolName(for config: MenuItemConfig) -> String {
        config.executionMode == .currentDirectory
            ? currentDirectorySymbolName
            : applicationPlaceholderSymbolName
    }
}
