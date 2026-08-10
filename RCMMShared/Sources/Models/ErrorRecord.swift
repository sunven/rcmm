import Foundation

public enum ErrorRecordKind: String, Codable, Hashable, Sendable {
    case scriptCompile
    case scriptPublish
    case scriptLoad
    case scriptExecution
}

public struct ErrorRecord: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let source: String
    public let message: String
    public let context: String?
    public let key: String?
    public let kind: ErrorRecordKind?

    enum CodingKeys: String, CodingKey {
        case id, timestamp, source, message, context, key, kind
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: String,
        message: String,
        context: String? = nil,
        key: String? = nil,
        kind: ErrorRecordKind? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.message = message
        self.context = context
        self.key = key
        self.kind = kind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        source = try container.decode(String.self, forKey: .source)
        message = try container.decode(String.self, forKey: .message)
        context = try container.decodeIfPresent(String.self, forKey: .context)
        key = try container.decodeIfPresent(String.self, forKey: .key)
        kind = try container.decodeIfPresent(ErrorRecordKind.self, forKey: .kind)
    }

    /// Finder 运行期错误使用的稳定 key。脚本 ID 可以包含 `.`，因此消费端按固定前后缀解析。
    public static func runtimeScriptKey(scriptID: String, kind: ErrorRecordKind) -> String {
        "script.\(scriptID).\(kind.rawValue)"
    }

    /// Finder 运行期加载或执行错误所指向的脚本 ID。
    public var runtimeScriptID: String? {
        guard let kind,
              kind == .scriptLoad || kind == .scriptExecution,
              let key else {
            return nil
        }

        let prefix = "script."
        let suffix = ".\(kind.rawValue)"
        guard key.hasPrefix(prefix), key.hasSuffix(suffix) else { return nil }

        let scriptID = key.dropFirst(prefix.count).dropLast(suffix.count)
        return scriptID.isEmpty ? nil : String(scriptID)
    }
}
