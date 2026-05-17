import Foundation

public struct CompositeMenuItemConfig: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var iconName: String?
    public var steps: [CompositeCommandStep]
    public var isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, iconName, steps, isEnabled
    }

    public init(
        id: UUID = UUID(),
        name: String,
        iconName: String? = nil,
        steps: [CompositeCommandStep],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.steps = steps
        self.isEnabled = isEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
        steps = try container.decodeIfPresent([CompositeCommandStep].self, forKey: .steps) ?? []
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}
