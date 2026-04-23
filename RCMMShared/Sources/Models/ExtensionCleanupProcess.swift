public struct ExtensionCleanupProcess: Equatable, Codable, Identifiable, Sendable {
    public let pid: Int32
    public let appPath: String

    public init(pid: Int32, appPath: String) {
        self.pid = pid
        self.appPath = appPath
    }

    public var id: Int32 { pid }
}
