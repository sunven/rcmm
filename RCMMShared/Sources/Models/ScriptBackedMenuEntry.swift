import Foundation

public enum ScriptBackedEntryKind: String, Codable, Hashable, Sendable {
    case custom
    case composite
}

public struct ScriptBackedMenuEntry: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: ScriptBackedEntryKind
    public let displayName: String
    public let fingerprint: String
    public let executableStepIDs: Set<UUID>

    public init(
        id: String,
        kind: ScriptBackedEntryKind,
        displayName: String,
        fingerprint: String,
        executableStepIDs: Set<UUID> = []
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.fingerprint = fingerprint
        self.executableStepIDs = executableStepIDs
    }
}

public enum MenuEntryScriptPolicy: Sendable {
    public static func scriptBackedEntry(for entry: MenuEntry) -> ScriptBackedMenuEntry? {
        switch entry {
        case .builtIn:
            return nil
        case .custom(let config):
            guard CustomCommandValidator.validate(config).isExecutable else { return nil }
            return ScriptBackedMenuEntry(
                id: config.id.uuidString,
                kind: .custom,
                displayName: config.appName,
                fingerprint: fingerprint(for: config)
            )
        case .composite(let config):
            let validation = CompositeMenuItemValidator.validate(config)
            guard validation.isExecutable else { return nil }
            return ScriptBackedMenuEntry(
                id: config.id.uuidString,
                kind: .composite,
                displayName: config.name,
                fingerprint: validation.fingerprint,
                executableStepIDs: validation.executableStepIDs
            )
        }
    }

    public static func fingerprint(for config: MenuItemConfig) -> String {
        ScriptFingerprint.make(fields: [
            "custom-v2",
            config.id.uuidString.lowercased(),
            config.appName,
            config.bundleId ?? "",
            config.appPath,
            config.customCommand ?? "",
            config.executionMode.rawValue,
            String(config.isEnabled),
        ])
    }
}
