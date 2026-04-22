import Foundation

public struct ExtensionInstallHealth: Equatable, Sendable {
    public let status: ExtensionStatus
    public let currentExtensionPath: String?
    public let enabledExtensionPaths: [String]

    public init(
        status: ExtensionStatus,
        currentExtensionPath: String?,
        enabledExtensionPaths: [String]
    ) {
        self.status = status
        self.currentExtensionPath = currentExtensionPath
        self.enabledExtensionPaths = enabledExtensionPaths
    }

    public var primaryEnabledPath: String? {
        enabledExtensionPaths.first
    }
}
