import Foundation

public enum ExtensionStatus: String, Codable, Sendable {
    case enabled
    case disabled
    case unknown

    /// 状态描述文本，用于 UI 显示和 VoiceOver 无障碍读取
    public var statusDescription: String {
        switch self {
        case .enabled: "Finder 扩展已启用"
        case .unknown: "扩展状态未知"
        case .disabled: "Finder 扩展未启用"
        }
    }
}
