import Foundation

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

    public init(
        appPath: String,
        extensionPath: String,
        source: ExtensionCleanupCandidateSource,
        disposition: ExtensionCleanupCandidateDisposition,
        skipReason: String?
    ) {
        self.appPath = appPath
        self.extensionPath = extensionPath
        self.source = source
        self.disposition = disposition
        self.skipReason = skipReason
    }

    public var id: String { appPath }
}
