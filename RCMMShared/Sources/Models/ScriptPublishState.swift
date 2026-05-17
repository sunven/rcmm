import Foundation

public enum ScriptPublishStatus: String, Codable, Hashable, Sendable {
    case current
    case compileFailed
}

public struct ScriptPublishState: Codable, Identifiable, Hashable, Sendable {
    public let entryID: String
    public var status: ScriptPublishStatus
    public var fingerprint: String
    public var updatedAt: Date
    public var errorSummary: String?

    public var id: String { entryID }

    public init(
        entryID: String,
        status: ScriptPublishStatus,
        fingerprint: String,
        updatedAt: Date = Date(),
        errorSummary: String? = nil
    ) {
        self.entryID = entryID
        self.status = status
        self.fingerprint = fingerprint
        self.updatedAt = updatedAt
        self.errorSummary = errorSummary
    }
}
