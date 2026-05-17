import Foundation

public final class ScriptPublishStore: @unchecked Sendable {
    private let preferences: SharedPreferencesStore

    public init(defaults: UserDefaults? = nil) {
        preferences = SharedPreferencesStore(defaults: defaults)
    }

    public func loadAll() -> [String: ScriptPublishState] {
        guard let data = preferences.data(forKey: SharedKeys.scriptPublishStates) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: ScriptPublishState].self, from: data)) ?? [:]
    }

    public func state(for entryID: String) -> ScriptPublishState? {
        loadAll()[entryID]
    }

    public func upsert(_ state: ScriptPublishState) {
        var states = loadAll()
        states[state.entryID] = state
        save(states)
    }

    public func remove(entryID: String) {
        var states = loadAll()
        states.removeValue(forKey: entryID)
        save(states)
    }

    public func removeAll(except expectedEntryIDs: Set<String>) {
        let filtered = loadAll().filter { expectedEntryIDs.contains($0.key) }
        save(filtered)
    }

    public func replaceAll(with states: [String: ScriptPublishState]) {
        save(states)
    }

    public func removeAll() {
        preferences.removeObject(forKey: SharedKeys.scriptPublishStates)
    }

    private func save(_ states: [String: ScriptPublishState]) {
        guard !states.isEmpty else {
            removeAll()
            return
        }
        guard let data = try? JSONEncoder().encode(states) else {
            return
        }
        preferences.set(data, forKey: SharedKeys.scriptPublishStates)
    }
}
