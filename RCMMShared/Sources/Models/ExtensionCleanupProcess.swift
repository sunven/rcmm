public struct ExtensionCleanupProcess: Equatable, Codable, Identifiable, Sendable {
    public let pid: Int32
    public let appPath: String

    public init?(pid: Int32, appPath: String) {
        guard pid > 0 else { return nil }

        self.pid = pid
        self.appPath = appPath
    }

    enum CodingKeys: String, CodingKey {
        case pid
        case appPath
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let pid = try container.decode(Int32.self, forKey: .pid)
        let appPath = try container.decode(String.self, forKey: .appPath)

        guard let process = Self(pid: pid, appPath: appPath) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid extension cleanup process state."
                )
            )
        }

        self = process
    }

    public var id: Int32 { pid }
}
