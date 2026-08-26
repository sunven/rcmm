import Foundation

public enum BuiltInType: String, Codable, Sendable, CaseIterable {
    case copyPath
    case cleanNodeModules

    public var requiresPublishedScript: Bool {
        switch self {
        case .copyPath: return false
        case .cleanNodeModules: return true
        }
    }
}
