import Foundation

public enum FinderMenuIconPolicy: Sendable {
    public static let applicationPlaceholderSymbolName = "app"
    public static let currentDirectorySymbolName = "terminal"

    public static func applicationIconData(
        for config: MenuItemConfig,
        cachedIcons: [String: Data]
    ) -> Data? {
        guard config.executionMode == .selectedPath else {
            return nil
        }
        return cachedIcons[config.id.uuidString]
    }

    public static func placeholderSymbolName(for config: MenuItemConfig) -> String {
        config.executionMode == .currentDirectory
            ? currentDirectorySymbolName
            : applicationPlaceholderSymbolName
    }
}
