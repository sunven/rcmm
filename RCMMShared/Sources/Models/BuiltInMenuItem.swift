import Foundation

public struct BuiltInMenuItem: Codable, Hashable, Sendable {
    public let type: BuiltInType
    public var isEnabled: Bool

    public init(type: BuiltInType, isEnabled: Bool) {
        self.type = type
        self.isEnabled = isEnabled
    }

    public var displayName: String {
        if let profile = type.cleanupProfile {
            return "清理 \(profile.noun)"
        }
        return "拷贝路径"
    }

    public var iconName: String {
        type.isCleanup ? "trash" : "doc.on.clipboard"
    }
}
