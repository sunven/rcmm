import Foundation

public struct BuiltInMenuItem: Codable, Hashable, Sendable {
    public let type: BuiltInType
    public var isEnabled: Bool

    public init(type: BuiltInType, isEnabled: Bool) {
        self.type = type
        self.isEnabled = isEnabled
    }

    public var displayName: String {
        switch type {
        case .copyPath: return "拷贝路径"
        }
    }

    public var iconName: String {
        switch type {
        case .copyPath: return "doc.on.clipboard"
        }
    }
}
