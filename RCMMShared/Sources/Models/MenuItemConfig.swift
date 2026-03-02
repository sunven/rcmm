import Foundation

public struct MenuItemConfig: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var appName: String
    public var bundleId: String?
    public var appPath: String
    public var customCommand: String?
    public var sortOrder: Int
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        appName: String,
        bundleId: String? = nil,
        appPath: String,
        customCommand: String? = nil,
        sortOrder: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.appName = appName
        self.bundleId = bundleId
        self.appPath = appPath
        self.customCommand = customCommand
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
    }
}
