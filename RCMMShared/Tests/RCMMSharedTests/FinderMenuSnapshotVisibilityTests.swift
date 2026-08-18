import Foundation
import Testing
@testable import RCMMShared

@Suite("FinderMenuSnapshot 可见性测试")
struct FinderMenuSnapshotVisibilityTests {
    @Test("启用的 Built-in Entry 无需发布状态即可显示")
    func builtInVisibleWithoutPublishState() {
        let entry = MenuEntry.builtIn(
            BuiltInMenuItem(type: .copyPath, isEnabled: true)
        )

        let snapshot = makeSnapshot(entries: [entry], publishStates: [:])

        #expect(snapshot.visibleEntryCount == 1)
        #expect(snapshot.descriptors.count == 1)
        #expect(snapshot.descriptors.first?.action == .builtIn(.copyPath))
    }

    @Test("停用的 Menu Entry 不显示")
    func disabledEntryIsHidden() {
        let config = MenuItemConfig(
            appName: "Terminal",
            appPath: "/Applications/Utilities/Terminal.app",
            isEnabled: false
        )
        let entry = MenuEntry.custom(config)

        let snapshot = makeSnapshot(entries: [entry], publishStates: [:])

        #expect(snapshot.visibleEntryCount == 0)
        #expect(snapshot.descriptors.isEmpty)
    }

    @Test("custom 只有 current 且 fingerprint 匹配才显示")
    func customRequiresCurrentMatchingPublishState() {
        let config = MenuItemConfig(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            appName: "Terminal",
            appPath: "/Applications/Utilities/Terminal.app"
        )
        let entry = MenuEntry.custom(config)
        let scriptBackedEntry = MenuEntryEvaluator.evaluate(entry).scriptBacked[0]

        let current = makeSnapshot(
            entries: [entry],
            publishStates: [scriptBackedEntry.id: currentState(for: scriptBackedEntry)]
        )
        #expect(current.visibleEntryCount == 1)
        #expect(current.descriptors.count == 1)

        let stale = makeSnapshot(
            entries: [entry],
            publishStates: [
                scriptBackedEntry.id: ScriptPublishState(
                    entryID: scriptBackedEntry.id,
                    status: .current,
                    fingerprint: "stale"
                ),
            ]
        )
        #expect(stale.visibleEntryCount == 0)
        #expect(stale.descriptors.isEmpty)

        let failed = makeSnapshot(
            entries: [entry],
            publishStates: [
                scriptBackedEntry.id: ScriptPublishState(
                    entryID: scriptBackedEntry.id,
                    status: .compileFailed,
                    fingerprint: scriptBackedEntry.fingerprint
                ),
            ]
        )
        #expect(failed.visibleEntryCount == 0)
        #expect(failed.descriptors.isEmpty)
    }

    @Test("composite 必须可执行且发布状态匹配")
    func compositeRequiresExecutableAndMatchingPublishState() {
        let composite = CompositeMenuItemConfig(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "VS Code + Terminal",
            steps: [
                CompositeCommandStep(
                    id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    kind: .shell,
                    name: "Terminal",
                    commandTemplate: "open -a Terminal {path}"
                ),
            ]
        )
        let entry = MenuEntry.composite(composite)
        let scriptBackedEntry = MenuEntryEvaluator.evaluate(entry).scriptBacked[0]

        let current = makeSnapshot(
            entries: [entry],
            publishStates: [scriptBackedEntry.id: currentState(for: scriptBackedEntry)]
        )
        #expect(current.visibleEntryCount == 1)
        #expect(current.descriptors.count == 1)

        let invalidEntry = MenuEntry.composite(
            CompositeMenuItemConfig(
                id: composite.id,
                name: "Invalid",
                steps: []
            )
        )
        let invalid = makeSnapshot(
            entries: [invalidEntry],
            publishStates: [scriptBackedEntry.id: currentState(for: scriptBackedEntry)]
        )
        #expect(invalid.visibleEntryCount == 0)
        #expect(invalid.descriptors.isEmpty)
    }

    @Test("New File Menu 只保留发布状态匹配的模板")
    func newFileKeepsOnlyCurrentTemplates() {
        let menu = NewFileMenuConfig(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            name: "新建",
            templates: [
                NewFileTemplateConfig(
                    id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                    displayName: "txt",
                    fileExtension: "txt",
                    creationMode: .emptyFile
                ),
                NewFileTemplateConfig(
                    id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
                    displayName: "md",
                    fileExtension: "md",
                    creationMode: .textContent,
                    initialContent: "# Untitled\n"
                ),
            ]
        )
        let entry = MenuEntry.newFile(menu)
        let currentTemplate = MenuEntryEvaluator.evaluate(entry).scriptBacked[0]

        let snapshot = makeSnapshot(
            entries: [entry],
            publishStates: [currentTemplate.id: currentState(for: currentTemplate)]
        )

        #expect(snapshot.visibleEntryCount == 1)
        #expect(snapshot.descriptors.count == 1)
        #expect(snapshot.descriptors.first?.children.map(\.title) == ["txt"])
    }

    @Test("全部 New File Template 过期时父菜单隐藏")
    func newFileHidesWhenAllTemplatesAreStale() {
        let menu = NewFileMenuConfig(
            name: "新建",
            templates: [
                NewFileTemplateConfig(
                    displayName: "txt",
                    fileExtension: "txt",
                    creationMode: .emptyFile
                ),
            ]
        )
        let entry = MenuEntry.newFile(menu)
        let scriptBackedEntry = MenuEntryEvaluator.evaluate(entry).scriptBacked[0]

        let snapshot = makeSnapshot(
            entries: [entry],
            publishStates: [
                scriptBackedEntry.id: ScriptPublishState(
                    entryID: scriptBackedEntry.id,
                    status: .current,
                    fingerprint: "stale"
                ),
            ]
        )

        #expect(snapshot.visibleEntryCount == 0)
        #expect(snapshot.descriptors.isEmpty)
    }

    private func makeSnapshot(
        entries: [MenuEntry],
        publishStates: [String: ScriptPublishState]
    ) -> FinderMenuSnapshot {
        FinderMenuSnapshot(
            entries: entries,
            publishStates: publishStates,
            presentationMode: .flat,
            applicationIcons: [:],
            generation: 1
        )
    }

    private func currentState(
        for scriptBackedEntry: ScriptBackedMenuEntry
    ) -> ScriptPublishState {
        ScriptPublishState(
            entryID: scriptBackedEntry.id,
            status: .current,
            fingerprint: scriptBackedEntry.fingerprint
        )
    }
}
