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

    public static func noOp(message: String, followUpAdvice: [String]) -> ExtensionCleanupResult {
        Self(
            uncheckedOutcome: .noOp,
            completedSteps: [],
            failedStep: nil,
            deletedAppPaths: [],
            terminatedProcessIDs: [],
            message: message,
            followUpAdvice: followUpAdvice
        )
    }

    enum CodingKeys: String, CodingKey {
        case outcome
        case completedSteps
        case failedStep
        case deletedAppPaths
        case terminatedProcessIDs
        case message
        case followUpAdvice
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let outcome = try container.decode(ExtensionCleanupOutcome.self, forKey: .outcome)
        let completedSteps = try container.decode([ExtensionCleanupStep].self, forKey: .completedSteps)
        let failedStep = try container.decodeIfPresent(ExtensionCleanupStep.self, forKey: .failedStep)
        let deletedAppPaths = try container.decode([String].self, forKey: .deletedAppPaths)
        let terminatedProcessIDs = try container.decode([Int32].self, forKey: .terminatedProcessIDs)
        let message = try container.decode(String.self, forKey: .message)
        let followUpAdvice = try container.decode([String].self, forKey: .followUpAdvice)

        guard let result = Self(
            outcome: outcome,
            completedSteps: completedSteps,
            failedStep: failedStep,
            deletedAppPaths: deletedAppPaths,
            terminatedProcessIDs: terminatedProcessIDs,
            message: message,
            followUpAdvice: followUpAdvice
        ) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid extension cleanup result state."
                )
            )
        }

        self = result
    }

    private init(
        uncheckedOutcome: ExtensionCleanupOutcome,
        completedSteps: [ExtensionCleanupStep],
        failedStep: ExtensionCleanupStep?,
        deletedAppPaths: [String],
        terminatedProcessIDs: [Int32],
        message: String,
        followUpAdvice: [String]
    ) {
        self.outcome = uncheckedOutcome
        self.completedSteps = completedSteps
        self.failedStep = failedStep
        self.deletedAppPaths = deletedAppPaths
        self.terminatedProcessIDs = terminatedProcessIDs
        self.message = message
        self.followUpAdvice = followUpAdvice
    }
}
