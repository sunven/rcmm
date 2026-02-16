import Foundation

public struct MenuItemConfig: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var appName: String
    public var bundleId: String?
    public var appPath: String
    public var customCommand: String?
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        appName: String,
        bundleId: String? = nil,
        appPath: String,
        customCommand: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.appPath = appPath
        self.customCommand = customCommand
        self.sortOrder = sortOrder
    }
}
