import Foundation
import Observation
import RCMMShared

@Observable
@MainActor
final class OnboardingVerification {
    enum Phase {
        case idle, syncing, finished
    }

    struct Item: Identifiable {
        let id: String
        let name: String
        let issue: String?
    }

    private(set) var phase: Phase = .idle
    private(set) var targets: [MenuEntry] = []
    private var confirmedEntries: [MenuEntry]?
    @ObservationIgnored private(set) var task: Task<Void, Never>?
    private var generation = 0

    static func existingApplication(in entries: [MenuEntry]) -> MenuEntry? {
        entries.first {
            guard case .custom(let config) = $0 else { return false }
            return config.isEnabled && config.executionMode == .selectedPath && !config.appPath.isEmpty
        }
    }

    func prepare(apps: [AppInfo], coordinator: AppCoordinator) {
        guard phase != .syncing else { return }
        let existingIDs = Set(coordinator.configStore.menuEntries.map(\.id))
        targets.removeAll { !existingIDs.contains($0.id) }
        let newApps = apps.filter {
            !AppPickerItemMatcher.isAlreadyAdded($0, in: coordinator.configStore.menuEntries)
        }
        if !newApps.isEmpty {
            let addedIDs = coordinator.edit { $0.addMenuItems(from: newApps) }
            let addedIDStrings = Set(addedIDs.map(\.uuidString))
            targets.append(contentsOf: coordinator.configStore.menuEntries.filter {
                addedIDStrings.contains($0.id)
            })
        }
        if targets.isEmpty,
           let existing = Self.existingApplication(in: coordinator.configStore.menuEntries) {
            targets = [existing]
        }
        startWaiting(coordinator: coordinator, republish: newApps.isEmpty)
    }

    func retry(coordinator: AppCoordinator) {
        guard phase != .syncing else { return }
        startWaiting(coordinator: coordinator, republish: true)
    }

    func leave() {
        generation += 1
        task?.cancel()
        task = nil
        phase = .idle
        confirmedEntries = nil
    }

    func currentEntries(in store: MenuConfigStore) -> [MenuEntry] {
        targets.compactMap { target in store.menuEntries.first { $0.id == target.id } }
    }

    func items(in store: MenuConfigStore) -> [Item] {
        targets.map { target in
            guard let entry = store.menuEntries.first(where: { $0.id == target.id }) else {
                return Item(id: target.id, name: target.displayName, issue: "菜单项已删除，请返回选择应用")
            }
            return Item(id: entry.id, name: entry.displayName, issue: issue(for: entry, in: store))
        }
    }

    func isReady(in store: MenuConfigStore) -> Bool {
        phase == .finished && !targets.isEmpty && items(in: store).allSatisfy { $0.issue == nil }
    }

    func isConfirmed(in store: MenuConfigStore) -> Bool {
        isReady(in: store) && confirmedEntries == currentEntries(in: store)
    }

    func confirm(_ value: Bool, in store: MenuConfigStore) {
        confirmedEntries = value && isReady(in: store) ? currentEntries(in: store) : nil
    }

    private func startWaiting(coordinator: AppCoordinator, republish: Bool) {
        generation += 1
        let request = generation
        confirmedEntries = nil
        phase = .syncing
        task = Task { @MainActor [weak self] in
            if republish {
                await coordinator.synchronizeScripts()
            } else {
                await coordinator.waitForCurrentPublication()
            }
            guard let self, !Task.isCancelled, self.generation == request else { return }
            self.phase = .finished
        }
    }

    private func issue(for entry: MenuEntry, in store: MenuConfigStore) -> String? {
        guard entry.isEnabled else { return "菜单项已停用，请在设置中启用" }
        let evaluation = MenuEntryEvaluator.evaluate(entry, environment: .filesystemAware)
        if let error = evaluation.errors.first { return error.message }
        guard !evaluation.scriptBacked.isEmpty else { return "没有可执行的应用命令" }
        for script in evaluation.scriptBacked {
            guard let state = store.scriptPublishStates[script.id],
                  state.fingerprint == script.fingerprint else {
                return "配置尚未同步成功，请重新同步"
            }
            guard state.status == .current else {
                return state.errorSummary ?? "脚本同步失败，请重新同步"
            }
        }
        return nil
    }
}
