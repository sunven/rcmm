import Foundation

public enum AppCategory: String, Codable, Sendable, CaseIterable, Comparable {
    case terminal
    case editor
    case other

    public var sortWeight: Int {
        switch self {
        case .terminal: return 0
        case .editor: return 1
        case .other: return 2
        }
    }

    public static func < (lhs: AppCategory, rhs: AppCategory) -> Bool {
        lhs.sortWeight < rhs.sortWeight
    }
}
