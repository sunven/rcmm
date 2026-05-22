import Foundation

public enum MenuEntry: Codable, Identifiable, Hashable, Sendable {
    case builtIn(BuiltInMenuItem)
    case custom(MenuItemConfig)
    case composite(CompositeMenuItemConfig)
    case newFile(NewFileMenuConfig)

    enum LegacyCodingKeys: String, CodingKey {
        case builtIn, custom, composite, newFile
    }

    public var id: String {
        switch self {
        case .builtIn(let item):
            return "builtIn.\(item.type.rawValue)"
        case .custom(let config):
            return config.id.uuidString
        case .composite(let config):
            return config.id.uuidString
        case .newFile(let config):
            return config.id.uuidString
        }
    }

    public var isEnabled: Bool {
        switch self {
        case .builtIn(let item): return item.isEnabled
        case .custom(let config): return config.isEnabled
        case .composite(let config): return config.isEnabled
        case .newFile(let config): return config.isEnabled
        }
    }

    public var displayName: String {
        switch self {
        case .builtIn(let item): return item.displayName
        case .custom(let config): return config.appName
        case .composite(let config): return config.name
        case .newFile(let config): return config.name
        }
    }

    public var systemSymbolName: String? {
        switch self {
        case .builtIn(let item): return item.iconName
        case .custom: return nil
        case .composite(let config): return config.iconName
        case .newFile(let config): return config.iconName
        }
    }

    public var isBuiltIn: Bool {
        if case .builtIn = self { return true }
        return false
    }

    var envelopeType: String {
        switch self {
        case .builtIn:
            return MenuEntryType.builtIn.rawValue
        case .custom:
            return MenuEntryType.custom.rawValue
        case .composite:
            return MenuEntryType.composite.rawValue
        case .newFile:
            return MenuEntryType.newFile.rawValue
        }
    }

    public init(from decoder: Decoder) throws {
        let envelope = try MenuEntryEnvelope(from: decoder)
        if let entry = envelope.entry {
            self = entry
            return
        }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown menu entry type: \(envelope.type)"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: LegacyCodingKeys.self)
        switch self {
        case .builtIn(let item):
            try container.encode(item, forKey: .builtIn)
        case .custom(let config):
            try container.encode(config, forKey: .custom)
        case .composite(let config):
            try container.encode(config, forKey: .composite)
        case .newFile(let config):
            try container.encode(config, forKey: .newFile)
        }
    }
}
