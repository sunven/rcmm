import Foundation

public enum ScriptBackedEntryKind: String, Codable, Hashable, Sendable {
    case custom
    case composite
    case newFileTemplate
}

public enum ScriptBackedMenuSource: Codable, Hashable, Sendable {
    case custom(id: UUID)
    case composite(id: UUID, executableStepIDs: Set<UUID>)
    case newFileTemplate(menuID: UUID, templateID: UUID)
}

public enum ScriptBackedTargetPolicy: String, Codable, Hashable, Sendable {
    case selectedPath
    case containingDirectory
}

public struct ScriptBackedMenuEntry: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let kind: ScriptBackedEntryKind
    public let displayName: String
    public let parentDisplayName: String?
    public let fingerprint: String
    public let source: ScriptBackedMenuSource
    public let targetPolicy: ScriptBackedTargetPolicy

    public var executableStepIDs: Set<UUID> {
        guard case .composite(_, let executableStepIDs) = source else {
            return []
        }
        return executableStepIDs
    }

    public init(
        id: String,
        kind: ScriptBackedEntryKind,
        displayName: String,
        fingerprint: String,
        source: ScriptBackedMenuSource,
        targetPolicy: ScriptBackedTargetPolicy,
        parentDisplayName: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.parentDisplayName = parentDisplayName
        self.fingerprint = fingerprint
        self.source = source
        self.targetPolicy = targetPolicy
    }

    public init(
        id: String,
        kind: ScriptBackedEntryKind,
        displayName: String,
        fingerprint: String,
        executableStepIDs: Set<UUID> = []
    ) {
        let source: ScriptBackedMenuSource
        switch kind {
        case .custom:
            source = UUID(uuidString: id).map(ScriptBackedMenuSource.custom) ?? .custom(id: UUID())
        case .composite:
            source = .composite(id: UUID(uuidString: id) ?? UUID(), executableStepIDs: executableStepIDs)
        case .newFileTemplate:
            let parts = id.split(separator: ".", maxSplits: 1).map(String.init)
            source = .newFileTemplate(
                menuID: parts.first.flatMap(UUID.init(uuidString:)) ?? UUID(),
                templateID: parts.dropFirst().first.flatMap(UUID.init(uuidString:)) ?? UUID()
            )
        }
        self.init(
            id: id,
            kind: kind,
            displayName: displayName,
            fingerprint: fingerprint,
            source: source,
            targetPolicy: kind == .newFileTemplate ? .containingDirectory : .selectedPath
        )
    }
}

public enum MenuEntryScriptPolicy: Sendable {
    public static func scriptBackedEntries(for entry: MenuEntry) -> [ScriptBackedMenuEntry] {
        switch entry {
        case .builtIn:
            return []
        case .custom, .composite:
            return scriptBackedEntry(for: entry).map { [$0] } ?? []
        case .newFile(let config):
            let validation = NewFileMenuValidator.validate(
                config,
                fileInfo: configurationOnlyFileInfo
            )
            guard validation.isExecutable else { return [] }
            return config.templates.compactMap { template in
                guard validation.executableTemplateIDs.contains(template.id),
                      let fingerprint = validation.fingerprintByTemplateID[template.id] else {
                    return nil
                }
                return ScriptBackedMenuEntry(
                    id: newFileScriptID(menuID: config.id, templateID: template.id),
                    kind: .newFileTemplate,
                    displayName: template.displayName,
                    fingerprint: fingerprint,
                    source: .newFileTemplate(menuID: config.id, templateID: template.id),
                    targetPolicy: .containingDirectory,
                    parentDisplayName: config.name
                )
            }
        }
    }

    public static func scriptBackedEntry(for entry: MenuEntry) -> ScriptBackedMenuEntry? {
        switch entry {
        case .builtIn, .newFile:
            return nil
        case .custom(let config):
            guard CustomCommandValidator.validate(config).isExecutable else { return nil }
            return ScriptBackedMenuEntry(
                id: config.id.uuidString,
                kind: .custom,
                displayName: config.appName,
                fingerprint: fingerprint(for: config),
                source: .custom(id: config.id),
                targetPolicy: config.executionMode == .currentDirectory ? .containingDirectory : .selectedPath
            )
        case .composite(let config):
            let validation = CompositeMenuItemValidator.validate(config)
            guard validation.isExecutable else { return nil }
            return ScriptBackedMenuEntry(
                id: config.id.uuidString,
                kind: .composite,
                displayName: config.name,
                fingerprint: validation.fingerprint,
                source: .composite(id: config.id, executableStepIDs: validation.executableStepIDs),
                targetPolicy: .selectedPath
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

    public static func newFileScriptID(menuID: UUID, templateID: UUID) -> String {
        "\(menuID.uuidString).\(templateID.uuidString)"
    }

    private static func configurationOnlyFileInfo(path: String) -> NewFileTemplateFileInfo? {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }

        return NewFileTemplateFileInfo(
            isDirectory: false,
            pathExtension: URL(fileURLWithPath: trimmedPath).pathExtension
        )
    }
}
