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
                guard let scriptBackedEntry = MenuEntryScriptPolicy.scriptBackedEntry(for: entry),
                      let publishState = publishStates[scriptBackedEntry.id] else {
                    return false
                }
                return publishState.status == .current
                    && publishState.fingerprint == scriptBackedEntry.fingerprint
            }
        }
    }
}
