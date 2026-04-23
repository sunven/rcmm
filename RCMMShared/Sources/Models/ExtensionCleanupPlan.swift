public struct ExtensionCleanupPlan: Equatable, Codable, Sendable {
    public let currentAppPath: String?
    public let deleteCandidates: [ExtensionCleanupCandidate]
    public let skippedCandidates: [ExtensionCleanupCandidate]
    public let processesToTerminate: [ExtensionCleanupProcess]
    public let postCleanupCommands: [String]

    public init?(
        currentAppPath: String?,
        deleteCandidates: [ExtensionCleanupCandidate],
        skippedCandidates: [ExtensionCleanupCandidate],
        processesToTerminate: [ExtensionCleanupProcess],
        postCleanupCommands: [String]
    ) {
        guard deleteCandidates.allSatisfy({ $0.disposition == .delete }) else { return nil }
        guard skippedCandidates.allSatisfy({ $0.disposition == .skip }) else { return nil }

        self.currentAppPath = currentAppPath
        self.deleteCandidates = deleteCandidates
        self.skippedCandidates = skippedCandidates
        self.processesToTerminate = processesToTerminate
        self.postCleanupCommands = postCleanupCommands
    }

    public var hasWork: Bool {
        !deleteCandidates.isEmpty || !processesToTerminate.isEmpty
    }

    public var summary: String {
        guard hasWork else {
            return "未发现可自动清理的旧副本或旧 rcmm 进程。"
        }
        guard !postCleanupCommands.isEmpty else {
            return "发现 \(deleteCandidates.count) 个旧副本，会结束 \(processesToTerminate.count) 个旧 rcmm 进程。"
        }
        return "发现 \(deleteCandidates.count) 个旧副本，会结束 \(processesToTerminate.count) 个旧 rcmm 进程，并在清理后自动切回当前扩展、重启 Finder。"
    }
}
