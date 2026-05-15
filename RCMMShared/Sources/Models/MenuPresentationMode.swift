import Foundation

public enum MenuPresentationMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case flat
    case nestedUnderRCMM

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .flat:
            return "平铺"
        case .nestedUnderRCMM:
            return "收进 RCMM"
        }
    }
}
