import Foundation

public struct AppInfo: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var bundleId: String?
    public var path: String
    public var category: AppCategory?

    public init(
        id: UUID = UUID(),
        name: String,
        bundleId: String? = nil,
        path: String,
        category: AppCategory? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleId = bundleId
        self.path = path
        self.category = category
    }
}
