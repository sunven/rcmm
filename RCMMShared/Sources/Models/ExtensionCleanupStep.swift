public enum ExtensionCleanupStep: String, Codable, Sendable, CaseIterable {
    case terminateProcesses
    case deleteApps
    case switchExtension
    case restartFinder
    case recheckHealth

    public var title: String {
        switch self {
        case .terminateProcesses: "正在结束旧 rcmm 进程"
        case .deleteApps: "正在删除旧扩展副本"
        case .switchExtension: "正在切换到当前扩展"
        case .restartFinder: "正在重启 Finder"
        case .recheckHealth: "正在重新检测状态"
        }
    }
}
