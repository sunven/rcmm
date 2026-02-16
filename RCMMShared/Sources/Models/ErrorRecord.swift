import Foundation

public struct ErrorRecord: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let source: String
    public let message: String
    public let context: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: String,
        message: String,
        context: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.message = message
        self.context = context
    }
}
