public enum ExtensionCleanupOutcome: String, Codable, Sendable {
    case success
    case partialSuccess
    case noOp
}

public struct ExtensionCleanupResult: Equatable, Codable, Sendable {
    public let outcome: ExtensionCleanupOutcome
    public let completedSteps: [ExtensionCleanupStep]
    public let failedStep: ExtensionCleanupStep?
    public let deletedAppPaths: [String]
    public let terminatedProcessIDs: [Int32]
    public let message: String
    public let followUpAdvice: [String]

    public init?(
        outcome: ExtensionCleanupOutcome,
        completedSteps: [ExtensionCleanupStep],
        failedStep: ExtensionCleanupStep?,
        deletedAppPaths: [String],
        terminatedProcessIDs: [Int32],
        message: String,
        followUpAdvice: [String]
    ) {
        switch outcome {
        case .success:
            guard failedStep == nil else { return nil }
        case .partialSuccess:
            guard failedStep != nil else { return nil }
        case .noOp:
            guard failedStep == nil else { return nil }
            guard completedSteps.isEmpty else { return nil }
            guard deletedAppPaths.isEmpty else { return nil }
            guard terminatedProcessIDs.isEmpty else { return nil }
        }

        self.outcome = outcome
        self.completedSteps = completedSteps
        self.failedStep = failedStep
        self.deletedAppPaths = deletedAppPaths
        self.terminatedProcessIDs = terminatedProcessIDs
        self.message = message
        self.followUpAdvice = followUpAdvice
    }
}
