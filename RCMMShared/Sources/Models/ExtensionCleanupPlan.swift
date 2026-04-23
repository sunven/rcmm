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

    enum CodingKeys: String, CodingKey {
        case currentAppPath
        case deleteCandidates
        case skippedCandidates
        case processesToTerminate
        case postCleanupCommands
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let currentAppPath = try container.decodeIfPresent(String.self, forKey: .currentAppPath)
        let deleteCandidates = try container.decode([ExtensionCleanupCandidate].self, forKey: .deleteCandidates)
        let skippedCandidates = try container.decode([ExtensionCleanupCandidate].self, forKey: .skippedCandidates)
        let processesToTerminate = try container.decode([ExtensionCleanupProcess].self, forKey: .processesToTerminate)
        let postCleanupCommands = try container.decode([String].self, forKey: .postCleanupCommands)

        guard let plan = Self(
            currentAppPath: currentAppPath,
            deleteCandidates: deleteCandidates,
            skippedCandidates: skippedCandidates,
            processesToTerminate: processesToTerminate,
            postCleanupCommands: postCleanupCommands
        ) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid extension cleanup plan state."
                )
            )
        }

        self = plan
    }

    public var hasWork: Bool {
        !deleteCandidates.isEmpty || !processesToTerminate.isEmpty
    }

    public var summary: String {
        guard hasWork else {
            return "未发现可自动清理的旧副本或旧 rcmm 进程。"
        }
        let coreSummary: String
        if !deleteCandidates.isEmpty && !processesToTerminate.isEmpty {
            coreSummary = "发现 \(deleteCandidates.count) 个旧副本，会结束 \(processesToTerminate.count) 个旧 rcmm 进程"
        } else if !deleteCandidates.isEmpty {
            coreSummary = "发现 \(deleteCandidates.count) 个旧副本"
        } else {
            coreSummary = "会结束 \(processesToTerminate.count) 个旧 rcmm 进程"
        }

        guard !postCleanupCommands.isEmpty else {
            return "\(coreSummary)。"
        }
        return "\(coreSummary)，并在清理后自动切回当前扩展、重启 Finder。"
    }
}
