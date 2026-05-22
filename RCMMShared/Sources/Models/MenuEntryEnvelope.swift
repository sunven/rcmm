import Foundation

public enum MenuEntryEnvelope: Codable, Hashable, Sendable {
    case known(MenuEntry)
    case unknown(type: String, payload: JSONValue)

    private enum CodingKeys: String, CodingKey {
        case type, payload
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case builtIn, custom, composite, newFile
    }

    public init(entry: MenuEntry) {
        self = .known(entry)
    }

    public var entry: MenuEntry? {
        switch self {
        case .known(let entry):
            return entry
        case .unknown:
            return nil
        }
    }

    public var isUnknown: Bool {
        if case .unknown = self { return true }
        return false
    }

    public var type: String {
        switch self {
        case .known(let entry):
            return entry.envelopeType
        case .unknown(let type, _):
            return type
        }
    }

    public init(from decoder: Decoder) throws {
        if let envelope = try Self.decodeEnvelope(from: decoder) {
            self = envelope
            return
        }

        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        if legacyContainer.contains(.builtIn) {
            self = .known(.builtIn(try legacyContainer.decode(BuiltInMenuItem.self, forKey: .builtIn)))
        } else if legacyContainer.contains(.custom) {
            self = .known(.custom(try legacyContainer.decode(MenuItemConfig.self, forKey: .custom)))
        } else if legacyContainer.contains(.composite) {
            self = .known(.composite(try legacyContainer.decode(CompositeMenuItemConfig.self, forKey: .composite)))
        } else if legacyContainer.contains(.newFile) {
            self = .known(.newFile(try legacyContainer.decode(NewFileMenuConfig.self, forKey: .newFile)))
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported menu entry envelope"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        switch self {
        case .known(let entry):
            switch entry {
            case .builtIn(let item):
                try container.encode(item, forKey: .payload)
            case .custom(let config):
                try container.encode(config, forKey: .payload)
            case .composite(let config):
                try container.encode(config, forKey: .payload)
            case .newFile(let config):
                try container.encode(config, forKey: .payload)
            }
        case .unknown(_, let payload):
            try container.encode(payload, forKey: .payload)
        }
    }

    private static func decodeEnvelope(from decoder: Decoder) throws -> MenuEntryEnvelope? {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self),
              container.contains(.type) else {
            return nil
        }

        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case MenuEntryType.builtIn.rawValue:
            return .known(.builtIn(try container.decode(BuiltInMenuItem.self, forKey: .payload)))
        case MenuEntryType.custom.rawValue:
            return .known(.custom(try container.decode(MenuItemConfig.self, forKey: .payload)))
        case MenuEntryType.composite.rawValue:
            return .known(.composite(try container.decode(CompositeMenuItemConfig.self, forKey: .payload)))
        case MenuEntryType.newFile.rawValue:
            return .known(.newFile(try container.decode(NewFileMenuConfig.self, forKey: .payload)))
        default:
            let payload = try container.decodeIfPresent(JSONValue.self, forKey: .payload) ?? .null
            return .unknown(type: type, payload: payload)
        }
    }
}

enum MenuEntryType: String {
    case builtIn
    case custom
    case composite
    case newFile
}
