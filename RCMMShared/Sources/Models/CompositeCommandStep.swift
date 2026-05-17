import Foundation

public enum CompositeCommandStepKind: String, Codable, Hashable, Sendable {
    case app
    case shell
}

public struct CompositeCommandStep: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var kind: CompositeCommandStepKind
    public var name: String
    public var commandTemplate: String
    public var appPath: String?
    public var bundleId: String?
    public var isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, kind, name, commandTemplate, appPath, bundleId, isEnabled
    }

    public init(
        id: UUID = UUID(),
        kind: CompositeCommandStepKind,
        name: String,
        commandTemplate: String,
        appPath: String? = nil,
        bundleId: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.commandTemplate = commandTemplate
        self.appPath = appPath
        self.bundleId = bundleId
        self.isEnabled = isEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(CompositeCommandStepKind.self, forKey: .kind)
        name = try container.decode(String.self, forKey: .name)
        commandTemplate = try container.decode(String.self, forKey: .commandTemplate)
        appPath = try container.decodeIfPresent(String.self, forKey: .appPath)
        bundleId = try container.decodeIfPresent(String.self, forKey: .bundleId)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}
