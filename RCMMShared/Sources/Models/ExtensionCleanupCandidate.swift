public enum ExtensionCleanupCandidateSource: String, Codable, Sendable {
    case pluginKit
    case derivedData
    case devRelease
    case unsupported
}

public enum ExtensionCleanupCandidateDisposition: String, Codable, Sendable {
    case delete
    case skip
}

public struct ExtensionCleanupCandidate: Equatable, Codable, Identifiable, Sendable {
    public let appPath: String
    public let extensionPath: String
    public let source: ExtensionCleanupCandidateSource
    public let disposition: ExtensionCleanupCandidateDisposition
    public let skipReason: String?

    public init?(
        appPath: String,
        extensionPath: String,
        source: ExtensionCleanupCandidateSource,
        disposition: ExtensionCleanupCandidateDisposition,
        skipReason: String?
    ) {
        switch disposition {
        case .delete:
            guard skipReason == nil else { return nil }
            guard source != .unsupported else { return nil }
        case .skip:
            guard skipReason != nil else { return nil }
        }

        self.appPath = appPath
        self.extensionPath = extensionPath
        self.source = source
        self.disposition = disposition
        self.skipReason = skipReason
    }

    public var id: String { "\(appPath)#\(extensionPath)" }
}
