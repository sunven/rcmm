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

    enum CodingKeys: String, CodingKey {
        case appPath
        case extensionPath
        case source
        case disposition
        case skipReason
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let appPath = try container.decode(String.self, forKey: .appPath)
        let extensionPath = try container.decode(String.self, forKey: .extensionPath)
        let source = try container.decode(ExtensionCleanupCandidateSource.self, forKey: .source)
        let disposition = try container.decode(ExtensionCleanupCandidateDisposition.self, forKey: .disposition)
        let skipReason = try container.decodeIfPresent(String.self, forKey: .skipReason)

        guard let candidate = Self(
            appPath: appPath,
            extensionPath: extensionPath,
            source: source,
            disposition: disposition,
            skipReason: skipReason
        ) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid extension cleanup candidate state."
                )
            )
        }

        self = candidate
    }

    public var id: String { "\(appPath)#\(extensionPath)" }
}
