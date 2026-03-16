import Foundation

public struct MenuItemConfig: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var appName: String
    public var bundleId: String?
    public var appPath: String
    public var customCommand: String?
    public var isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id, appName, bundleId, appPath, customCommand, isEnabled
    }

    public init(
        id: UUID = UUID(),
        appName: String,
        bundleId: String? = nil,
        appPath: String,
        customCommand: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.appPath = appPath
        self.customCommand = customCommand
        self.isEnabled = isEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        appName = try container.decode(String.self, forKey: .appName)
        bundleId = try container.decodeIfPresent(String.self, forKey: .bundleId)
        appPath = try container.decode(String.self, forKey: .appPath)
        customCommand = try container.decodeIfPresent(String.self, forKey: .customCommand)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }
}
