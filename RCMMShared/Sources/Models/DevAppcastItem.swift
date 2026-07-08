import Foundation

public struct DevAppcastItem: Equatable, Sendable {
    public let version: DevBuildVersion
    public let displayVersion: String
    public let archiveURL: URL
    public let releaseNotesURL: URL?
    public let archiveLength: Int
    public let signature: String

    public init(
        version: DevBuildVersion,
        displayVersion: String? = nil,
        archiveURL: URL,
        releaseNotesURL: URL?,
        archiveLength: Int,
        signature: String
    ) {
        self.version = version
        self.displayVersion = displayVersion ?? version.displayVersion
        self.archiveURL = archiveURL
        self.releaseNotesURL = releaseNotesURL
        self.archiveLength = archiveLength
        self.signature = signature
    }
}
