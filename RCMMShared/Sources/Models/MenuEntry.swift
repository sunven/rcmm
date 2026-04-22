import Foundation

public enum MenuEntry: Codable, Identifiable, Hashable, Sendable {
    case builtIn(BuiltInMenuItem)
    case custom(MenuItemConfig)

    public var id: String {
        switch self {
        case .builtIn(let item):
            return "builtIn.\(item.type.rawValue)"
        case .custom(let config):
            return config.id.uuidString
        }
    }

    public var isEnabled: Bool {
        switch self {
        case .builtIn(let item): return item.isEnabled
        case .custom(let config): return config.isEnabled
        }
    }

    public var displayName: String {
        switch self {
        case .builtIn(let item): return item.displayName
        case .custom(let config): return config.appName
        }
    }

    public var systemSymbolName: String? {
        switch self {
        case .builtIn(let item): return item.iconName
        case .custom: return nil
        }
    }

    public var isBuiltIn: Bool {
        if case .builtIn = self { return true }
        return false
    }
}
