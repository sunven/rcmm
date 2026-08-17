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

/// New File Template 的脚本 ID 格式。
///
/// 「哪些 Menu Entry 产出脚本」已迁入 `MenuEntryEvaluator` —— 那和「哪里有问题」是同一个问题。
/// 这里只留下 ID 的拼装规则，因为 `FinderMenuDescriptor` 需要独立于评估结果构造它。
public enum MenuEntryScriptPolicy: Sendable {
    public static func newFileScriptID(menuID: UUID, templateID: UUID) -> String {
        "\(menuID.uuidString).\(templateID.uuidString)"
    }
}
