import Foundation
import RCMMShared
import Testing
@testable import rcmm

@Suite("Settings drafts", .serialized)
@MainActor
struct SettingsDraftStoreTests {
    @Test("多模板编辑只保存指定模板，保留其他模板草稿")
    func saveOnlySelectedTemplate() async throws {
        let f = try Fixture()
        defer { f.harness.cleanup() }
        f.coordinator.edit { $0.addNewFileTemplate(to: f.menu.id) }
        await f.coordinator.waitForCurrentPublication()
        let second = try #require(f.savedMenu.templates.last)
        var firstDraft = f.template
        firstDraft.baseName = "First draft"
        var secondDraft = second
        secondDraft.baseName = "Second draft"
        f.drafts.updateTemplate(firstDraft, menuID: f.menu.id)
        f.drafts.updateTemplate(secondDraft, menuID: f.menu.id)
        let secondKey = SettingsDraftStore.Key.template(menuID: f.menu.id, templateID: second.id)
        #expect(f.drafts.save(secondKey))
        await f.coordinator.waitForCurrentPublication()
        #expect(f.savedTemplate.baseName == f.template.baseName)
        #expect(f.savedMenu.templates.last?.baseName == "Second draft")
        #expect(f.drafts.hasChanges(f.templateKey))
        #expect(!f.drafts.hasChanges(secondKey))
    }

    @Test("规范化后没有变化时清理草稿但不发布")
    func normalizedNoOp() throws {
        let f = try Fixture()
        defer { f.harness.cleanup() }
        var command = f.command
        command.appName = "  \(command.appName)  "
        f.drafts.updateCommand(command)
        #expect(f.drafts.hasChanges(f.commandKey))
        #expect(!f.drafts.save(f.commandKey))
        #expect(!f.drafts.hasChanges(f.commandKey))
        #expect(f.harness.notifier.postedConfigChangedCount == 0)
    }

    @Test("三类草稿在保存前均不落盘、不发布，保存各发布一次")
    func manualSaveOnly() async throws {
        let f = try Fixture()
        defer { f.harness.cleanup() }
        let before = f.harness.configService.loadEntries()
        var command = f.command
        command.appName = "  New command  "
        f.drafts.updateCommand(command)
        var composite = f.composite
        composite.name = "New composite"
        composite.steps.append(MenuConfigStore.makeShellStep())
        composite.steps.reverse()
        composite.iconName = "terminal"
        f.drafts.updateComposite(composite)
        var template = f.template
        template.initialContent = "Hello"
        template.creationMode = .textContent
        f.drafts.updateTemplate(template, menuID: f.menu.id)

        #expect(f.drafts.count == 3)
        #expect(f.store.menuEntries == before)
        #expect(f.harness.configService.loadEntries() == before)
        #expect(f.harness.notifier.postedConfigChangedCount == 0)
        #expect(f.drafts.save(f.commandKey))
        await f.coordinator.waitForCurrentPublication()
        #expect(f.savedCommand.appName == "New command")
        #expect(f.drafts.count == 2)
        #expect(f.drafts.save(f.compositeKey))
        await f.coordinator.waitForCurrentPublication()
        #expect(f.savedComposite.steps == composite.steps)
        #expect(f.savedComposite.iconName == "terminal")
        #expect(f.drafts.save(f.templateKey))
        await f.coordinator.waitForCurrentPublication()
        #expect(f.savedTemplate.initialContent == "Hello")
        #expect(f.drafts.count == 0)
        #expect(f.harness.notifier.postedConfigChangedCount == 3)
        #expect(!f.drafts.save(f.commandKey))
        #expect(f.harness.notifier.postedConfigChangedCount == 3)
    }

    @Test("错误阻止保存并保留草稿，警告不阻止保存")
    func invalidDraftsStayEditable() async throws {
        let f = try Fixture()
        defer { f.harness.cleanup() }
        var command = f.command
        command.customCommand = ""
        f.drafts.updateCommand(command)
        var composite = f.composite
        composite.steps[0].commandTemplate = ""
        f.drafts.updateComposite(composite)
        var template = f.template
        template.baseName = "bad/name"
        template.isEnabled = false
        f.drafts.updateTemplate(template, menuID: f.menu.id)
        for key in [f.commandKey, f.compositeKey, f.templateKey] {
            #expect(!f.drafts.canSave(key))
            #expect(!f.drafts.save(key))
            #expect(f.drafts.hasChanges(key))
        }
        #expect(f.harness.notifier.postedConfigChangedCount == 0)
        composite.steps[0].isEnabled = false
        composite.steps.append(CompositeCommandStep(kind: .shell, name: "Warning", commandTemplate: "pwd"))
        f.drafts.updateComposite(composite)
        #expect(f.drafts.issues(for: f.compositeKey).contains { $0.severity == .warning })
        #expect(f.drafts.save(f.compositeKey))
        await f.coordinator.waitForCurrentPublication()
        #expect(!f.savedComposite.steps[0].isEnabled)
    }

    @Test("丢弃还原整组内容，独立编辑对象的草稿互不影响")
    func discardAndSessionLifetime() throws {
        let f = try Fixture()
        defer { f.harness.cleanup() }
        var composite = f.composite
        composite.name = "Draft"
        composite.steps.removeAll()
        f.drafts.updateComposite(composite)
        var command = f.command
        command.customCommand = "ls"
        f.drafts.updateCommand(command)
        // Editors reconstructed from the same app-level store see the same draft.
        #expect(f.drafts.composite(for: f.savedComposite) == composite)
        #expect(f.drafts.command(for: f.savedCommand).customCommand == "ls")
        #expect(SettingsDraftStore(coordinator: f.coordinator).count == 0)
        f.drafts.discard(f.compositeKey)
        #expect(f.drafts.composite(for: f.savedComposite) == f.composite)
        #expect(f.drafts.hasChanges(f.commandKey))
        #expect(f.harness.notifier.postedConfigChangedCount == 0)
    }

    @Test("保存草稿保留最新顶层启停、顺序和其他模板")
    func preservesImmediateChanges() async throws {
        let f = try Fixture()
        defer { f.harness.cleanup() }
        var composite = f.composite
        composite.name = "Draft"
        f.drafts.updateComposite(composite)
        var template = f.template
        template.baseName = "Draft file"
        f.drafts.updateTemplate(template, menuID: f.menu.id)
        f.coordinator.edit { store in
            store.toggleEntry(for: composite.id.uuidString, isEnabled: false)
            store.menuEntries.reverse()
            store.addNewFileTemplate(to: f.menu.id)
        }
        await f.coordinator.waitForCurrentPublication()
        let order = f.store.menuEntries.map(\.id)
        #expect(!f.drafts.hasConflict(f.compositeKey))
        #expect(!f.drafts.hasConflict(f.templateKey))
        #expect(f.drafts.save(f.compositeKey))
        #expect(f.drafts.save(f.templateKey))
        await f.coordinator.waitForCurrentPublication()
        #expect(!f.savedComposite.isEnabled)
        #expect(f.store.menuEntries.map(\.id) == order)
        #expect(f.savedMenu.templates.count == 2)
        #expect(f.savedTemplate.baseName == "Draft file")
    }

    @Test("外部编辑发生冲突，覆盖须显式指定并仍须校验")
    func conflictResolution() async throws {
        let f = try Fixture()
        defer { f.harness.cleanup() }
        var command = f.command
        command.customCommand = "ls"
        f.drafts.updateCommand(command)
        f.coordinator.edit { $0.updateCustomCommand(for: command.id, name: "External", command: "date") }
        await f.coordinator.waitForCurrentPublication()
        #expect(f.drafts.hasConflict(f.commandKey))
        #expect(f.drafts.command(for: f.savedCommand).customCommand == "ls")
        #expect(!f.drafts.save(f.commandKey))
        command.customCommand = ""
        f.drafts.updateCommand(command)
        #expect(!f.drafts.save(f.commandKey, overwrite: true))
        command.customCommand = "ls"
        f.drafts.updateCommand(command)
        #expect(f.drafts.save(f.commandKey, overwrite: true))
        await f.coordinator.waitForCurrentPublication()
        #expect(f.savedCommand.customCommand == "ls")
        command.customCommand = "whoami"
        f.drafts.updateCommand(command)
        f.coordinator.edit { $0.updateCustomCommand(for: command.id, command: "date") }
        await f.coordinator.waitForCurrentPublication()
        f.drafts.discard(f.commandKey)
        #expect(f.drafts.command(for: f.savedCommand).customCommand == "date")
    }

    @Test("模板资源指纹刷新不产生修改或冲突，模板状态各自独立")
    func templateMetadataAndStatus() async throws {
        let f = try Fixture()
        defer { f.harness.cleanup() }
        f.coordinator.edit { _ in }
        await f.coordinator.waitForCurrentPublication()
        #expect(f.drafts.savedStatus(for: f.templateKey)?.kind == .ready)
        var template = f.template
        template.baseName = "Draft"
        f.drafts.updateTemplate(template, menuID: f.menu.id)
        f.store.menuEntries = f.store.menuEntries.map { entry in
            guard case .newFile(var menu) = entry else { return entry }
            menu.templates[0].templateFingerprint = NewFileTemplateFingerprint(path: "/unused", fileSize: 1, modificationTime: 1)
            return .newFile(menu)
        }
        #expect(!f.drafts.hasConflict(f.templateKey))
        #expect(f.drafts.template(for: f.savedTemplate, menuID: f.menu.id).baseName == "Draft")
        f.drafts.discard(f.templateKey)
        #expect(!f.drafts.hasChanges(f.templateKey))
        // Changed resource metadata makes the published script stale, but is not a user draft.
        #expect(f.drafts.savedStatus(for: f.templateKey)?.kind == .syncing)
        f.store.menuEntries = f.store.menuEntries.map { entry in
            guard case .newFile(var menu) = entry else { return entry }
            menu.templates[0].templateFingerprint = nil
            menu.templates.append(NewFileTemplateConfig(displayName: "Invalid sibling", fileExtension: "/", creationMode: .emptyFile))
            return .newFile(menu)
        }
        #expect(f.drafts.savedStatus(for: f.templateKey)?.kind == .ready)
    }

    @Test("删除对象后不能保存草稿或复活对象")
    func deletedTarget() async throws {
        let f = try Fixture()
        defer { f.harness.cleanup() }
        var command = f.command
        command.customCommand = "ls"
        f.drafts.updateCommand(command)
        f.coordinator.edit { $0.removeEntry(withID: command.id.uuidString) }
        await f.coordinator.waitForCurrentPublication()
        #expect(f.drafts.count == 0)
        #expect(!f.drafts.hasChanges(f.commandKey))
        #expect(!f.drafts.save(f.commandKey, overwrite: true))
        #expect(!f.store.menuEntries.contains { $0.id == command.id.uuidString })
    }

    @Test("保存后的同步失败与新草稿独立，重试不丢失新输入")
    func retryDoesNotDiscardDraft() async throws {
        let compiler = DraftRetryCompiler()
        let f = try Fixture(compiler: compiler)
        defer { f.harness.cleanup() }
        var command = f.command
        command.customCommand = "ls"
        f.drafts.updateCommand(command)
        #expect(f.drafts.save(f.commandKey))
        await f.coordinator.waitForCurrentPublication()
        #expect(!f.drafts.hasChanges(f.commandKey))
        #expect(f.drafts.savedStatus(for: f.commandKey)?.kind == .failed)
        command.customCommand = "date"
        f.drafts.updateCommand(command)
        compiler.allowSuccess()
        await f.drafts.retrySync()
        #expect(f.drafts.savedStatus(for: f.commandKey)?.kind == .ready)
        #expect(f.savedCommand.customCommand == "ls")
        #expect(f.drafts.command(for: f.savedCommand).customCommand == "date")
        #expect(f.drafts.hasChanges(f.commandKey))
    }
}

@MainActor
private struct Fixture {
    let harness: PipelineHarness
    let coordinator: AppCoordinator
    let drafts: SettingsDraftStore
    let command = MenuItemConfig(appName: "Command", appPath: "", customCommand: "pwd", executionMode: .currentDirectory)
    let composite = CompositeMenuItemConfig(name: "Composite", steps: [CompositeCommandStep(kind: .shell, name: "Open", commandTemplate: "open {path}")])
    let template = NewFileTemplateConfig(displayName: "Text", fileExtension: "txt", creationMode: .emptyFile)
    let menu: NewFileMenuConfig

    init(compiler: AppleScriptCompiling? = nil) throws {
        harness = try PipelineHarness(compiler: compiler)
        menu = NewFileMenuConfig(templates: [template])
        harness.configService.saveEntries([.custom(command), .composite(composite), .newFile(menu)])
        coordinator = harness.makeCoordinator()
        drafts = SettingsDraftStore(coordinator: coordinator)
    }

    var store: MenuConfigStore { coordinator.configStore }
    var commandKey: SettingsDraftStore.Key { .command(command.id) }
    var compositeKey: SettingsDraftStore.Key { .composite(composite.id) }
    var templateKey: SettingsDraftStore.Key { .template(menuID: menu.id, templateID: template.id) }
    var savedCommand: MenuItemConfig {
        store.menuEntries.compactMap { if case .custom(let c) = $0 { return c }; return nil }.first!
    }
    var savedComposite: CompositeMenuItemConfig {
        store.menuEntries.compactMap { if case .composite(let c) = $0 { return c }; return nil }.first!
    }
    var savedMenu: NewFileMenuConfig {
        store.menuEntries.compactMap { if case .newFile(let c) = $0 { return c }; return nil }.first!
    }
    var savedTemplate: NewFileTemplateConfig { savedMenu.templates.first { $0.id == template.id }! }
}

private final class DraftRetryCompiler: AppleScriptCompiling {
    private let lock = NSLock()
    private var fails = true
    func allowSuccess() { lock.lock(); fails = false; lock.unlock() }
    func compile(source: String, outputURL: URL) throws {
        lock.lock()
        let shouldFail = fails
        lock.unlock()
        if shouldFail { throw NSError(domain: "DraftTests", code: 1) }
        try Data("compiled".utf8).write(to: outputURL)
    }
}
