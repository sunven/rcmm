import Foundation

public enum FinderMenuPresenter: Sendable {
    public static func visibleEntries(
        entries: [MenuEntry],
        publishStates: [String: ScriptPublishState]
    ) -> [MenuEntry] {
        entries.filter { entry in
            guard entry.isEnabled else { return false }

            switch entry {
            case .builtIn:
                return true
            case .custom, .composite:
                guard let scriptBackedEntry = MenuEntryScriptPolicy.scriptBackedEntry(for: entry) else {
                    return false
                }
                return isCurrent(scriptBackedEntry, publishStates: publishStates)
            case .newFile(let config):
                return !visibleNewFileTemplates(
                    for: config,
                    publishStates: publishStates
                ).isEmpty
            }
        }
    }

    public static func visibleNewFileTemplates(
        for config: NewFileMenuConfig,
        publishStates: [String: ScriptPublishState]
    ) -> [NewFileTemplateConfig] {
        guard config.isEnabled else { return [] }

        let scriptBackedByTemplateID = Dictionary(
            uniqueKeysWithValues: MenuEntryScriptPolicy
                .scriptBackedEntries(for: .newFile(config))
                .compactMap { scriptBackedEntry -> (UUID, ScriptBackedMenuEntry)? in
                    guard case .newFileTemplate(_, let templateID) = scriptBackedEntry.source else {
                        return nil
                    }
                    return (templateID, scriptBackedEntry)
                }
        )

        return config.templates.filter { template in
            guard let scriptBackedEntry = scriptBackedByTemplateID[template.id] else {
                return false
            }
            return isCurrent(scriptBackedEntry, publishStates: publishStates)
        }
    }

    public static func isCurrent(
        _ scriptBackedEntry: ScriptBackedMenuEntry,
        publishStates: [String: ScriptPublishState]
    ) -> Bool {
        guard let publishState = publishStates[scriptBackedEntry.id] else {
            return false
        }
        return publishState.status == .current
            && publishState.fingerprint == scriptBackedEntry.fingerprint
    }
}
