import Foundation
import Observation
import RCMMShared

/// Settings drafts live for the app session and never enter the published configuration.
@Observable
@MainActor
final class SettingsDraftStore {
    enum Key: Hashable {
        case command(UUID)
        case composite(UUID)
        case template(menuID: UUID, templateID: UUID)
    }

    private struct CommandFields: Equatable {
        var name: String
        var command: String?
        var executionMode: CustomCommandExecutionMode
    }

    private struct CompositeFields: Equatable {
        var name: String
        var iconName: String?
        var steps: [CompositeCommandStep]
    }

    private enum Content: Equatable {
        case command(CommandFields)
        case composite(CompositeFields)
        case template(NewFileTemplateConfig)
    }

    private struct Draft {
        let baseline: Content
        var content: Content
    }

    private var drafts: [Key: Draft] = [:]
    private let coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        observeConfiguration()
    }

    var count: Int { drafts.keys.filter { savedContent(for: $0) != nil }.count }

    func hasChanges(_ key: Key) -> Bool {
        drafts[key] != nil && savedContent(for: key) != nil
    }

    func hasConflict(_ key: Key) -> Bool {
        guard let draft = drafts[key], let saved = savedContent(for: key) else { return false }
        return draft.baseline != saved && draft.content != saved
    }

    func command(for saved: MenuItemConfig) -> MenuItemConfig {
        var result = saved
        if case .command(let fields) = drafts[.command(saved.id)]?.content {
            result.appName = fields.name
            result.customCommand = fields.command
            result.executionMode = fields.executionMode
        }
        return result
    }

    func composite(for saved: CompositeMenuItemConfig) -> CompositeMenuItemConfig {
        var result = saved
        if case .composite(let fields) = drafts[.composite(saved.id)]?.content {
            result.name = fields.name
            result.iconName = fields.iconName
            result.steps = fields.steps
        }
        return result
    }

    func template(for saved: NewFileTemplateConfig, menuID: UUID) -> NewFileTemplateConfig {
        guard case .template(var result) = drafts[.template(menuID: menuID, templateID: saved.id)]?.content else {
            return saved
        }
        result.templateFingerprint = saved.templateFingerprint
        return result
    }

    func updateCommand(_ config: MenuItemConfig) {
        update(.command(config.id), content: commandContent(config))
    }

    func updateComposite(_ config: CompositeMenuItemConfig) {
        update(.composite(config.id), content: compositeContent(config))
    }

    func updateTemplate(_ config: NewFileTemplateConfig, menuID: UUID) {
        update(.template(menuID: menuID, templateID: config.id), content: templateContent(config))
    }

    func discard(_ key: Key) {
        drafts.removeValue(forKey: key)
    }

    func issues(for key: Key) -> [MenuEntryIssue] {
        guard var entry = editedEntry(for: key) else { return [] }
        // Disabling a parent does not make invalid editable fields saveable.
        switch entry {
        case .custom(var config):
            config.isEnabled = true
            entry = .custom(config)
        case .composite(var config):
            config.isEnabled = true
            entry = .composite(config)
        case .newFile(var config):
            config.isEnabled = true
            config.templates[0].isEnabled = true
            entry = .newFile(config)
        case .builtIn:
            break
        }
        let issues = MenuEntryEvaluator.evaluate(entry, environment: .filesystemAware).issues
        if case .template(_, let templateID) = key {
            return issues.filter { $0.childID == templateID }
        }
        return issues
    }

    func canSave(_ key: Key, overwrite: Bool = false) -> Bool {
        hasChanges(key) && (overwrite || !hasConflict(key))
            && !issues(for: key).contains { $0.severity == .error }
    }

    @discardableResult
    func save(_ key: Key, overwrite: Bool = false) -> Bool {
        guard canSave(key, overwrite: overwrite), let entry = editedEntry(for: key) else { return false }
        guard content(of: entry) != savedContent(for: key) else {
            discard(key)
            return false
        }
        coordinator.edit { store in
            switch entry {
            case .custom(let config):
                store.updateCustomCommand(
                    for: config.id,
                    name: config.appName,
                    command: config.customCommand,
                    executionMode: config.executionMode
                )
            case .composite(let config):
                store.updateCompositeContents(config)
            case .newFile(let menu):
                let template = menu.templates[0]
                store.updateNewFileTemplate(
                    menuID: menu.id, templateID: template.id,
                    displayName: template.displayName, baseName: template.baseName,
                    fileExtension: template.fileExtension, creationMode: template.creationMode,
                    templatePath: template.templatePath, initialContent: template.initialContent,
                    isEnabled: template.isEnabled
                )
            case .builtIn:
                break
            }
        }
        // Subsequent reads use the normalized, committed fields, not the old draft.
        discard(key)
        return true
    }

    func savedStatus(for key: Key) -> MenuEntryStatus? {
        guard let entry = savedEntry(for: key) else { return nil }
        if case .newFile(let menu) = entry, menu.templates.first?.isEnabled == false {
            return MenuEntryStatus(kind: .disabled, text: "已停用", detail: nil)
        }
        let evaluation = MenuEntryEvaluator.evaluate(entry, environment: .filesystemAware)
        return MenuEntryStatusResolver.status(
            for: entry,
            evaluation: evaluation,
            publishStates: coordinator.configStore.scriptPublishStates
        )
    }

    func retrySync() async {
        await coordinator.synchronizeScripts()
    }

    private func update(_ key: Key, content: Content) {
        guard let saved = savedContent(for: key) else { return }
        if content == saved {
            discard(key)
        } else {
            drafts[key] = Draft(baseline: drafts[key]?.baseline ?? saved, content: content)
        }
    }

    private func savedEntry(for key: Key) -> MenuEntry? {
        switch key {
        case .command(let id):
            return coordinator.configStore.menuEntries.first {
                if case .custom(let config) = $0 { return config.id == id }
                return false
            }
        case .composite(let id):
            return coordinator.configStore.menuEntries.first {
                if case .composite(let config) = $0 { return config.id == id }
                return false
            }
        case .template(let menuID, let templateID):
            for entry in coordinator.configStore.menuEntries {
                if case .newFile(var menu) = entry, menu.id == menuID,
                   let template = menu.templates.first(where: { $0.id == templateID }) {
                    menu.templates = [template]
                    return .newFile(menu)
                }
            }
            return nil
        }
    }

    private func editedEntry(for key: Key) -> MenuEntry? {
        guard let entry = savedEntry(for: key) else { return nil }
        switch entry {
        case .custom(let config):
            var draft = command(for: config)
            draft.appName = draft.appName.trimmingCharacters(in: .whitespacesAndNewlines)
            if draft.customCommand?.isEmpty == true { draft.customCommand = nil }
            return .custom(draft)
        case .composite(let config):
            var draft = composite(for: config)
            draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            draft.iconName = draft.iconName?.nilIfBlank
            return .composite(draft)
        case .newFile(var menu):
            var draft = template(for: menu.templates[0], menuID: menu.id)
            draft.templatePath = draft.creationMode == .copyTemplate ? draft.templatePath?.nilIfBlank : nil
            draft.initialContent = draft.creationMode == .textContent ? draft.initialContent?.nilIfBlank : nil
            menu.templates = [draft]
            return .newFile(menu)
        case .builtIn: return nil
        }
    }

    private func savedContent(for key: Key) -> Content? {
        guard let entry = savedEntry(for: key) else { return nil }
        return content(of: entry)
    }

    private func content(of entry: MenuEntry) -> Content? {
        switch entry {
        case .custom(let config): return commandContent(config)
        case .composite(let config): return compositeContent(config)
        case .newFile(let menu): return templateContent(menu.templates[0])
        case .builtIn: return nil
        }
    }

    private func commandContent(_ config: MenuItemConfig) -> Content {
        .command(CommandFields(name: config.appName, command: config.customCommand, executionMode: config.executionMode))
    }

    private func compositeContent(_ config: CompositeMenuItemConfig) -> Content {
        .composite(CompositeFields(name: config.name, iconName: config.iconName, steps: config.steps))
    }

    private func templateContent(_ config: NewFileTemplateConfig) -> Content {
        var fields = config
        fields.templateFingerprint = nil
        return .template(fields)
    }

    private func observeConfiguration() {
        withObservationTracking {
            _ = coordinator.configStore.menuEntries
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.drafts = self.drafts.filter { key, draft in
                    guard let saved = self.savedContent(for: key) else { return false }
                    return saved != draft.content
                }
                self.observeConfiguration()
            }
        }
    }
}
