import Foundation
import Testing
@testable import RCMMShared

@Suite("FinderMenuPresenter 测试")
struct FinderMenuPresenterTests {
    @Test("builtIn 无需发布状态即可显示")
    func builtInVisibleWithoutPublishState() {
        let copyPath = MenuEntry.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true))

        let visible = FinderMenuPresenter.visibleEntries(
            entries: [copyPath],
            publishStates: [:]
        )

        #expect(visible == [copyPath])
    }

    @Test("custom 只有 current 且 fingerprint 匹配才显示")
    func customRequiresCurrentMatchingPublishState() {
        let config = MenuItemConfig(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            appName: "Terminal",
            appPath: "/Applications/Utilities/Terminal.app"
        )
        let entry = MenuEntry.custom(config)
        let fingerprint = MenuEntryScriptPolicy.fingerprint(for: config)

        let visible = FinderMenuPresenter.visibleEntries(
            entries: [entry],
            publishStates: [
                config.id.uuidString: ScriptPublishState(
                    entryID: config.id.uuidString,
                    status: .current,
                    fingerprint: fingerprint
                ),
            ]
        )

        #expect(visible == [entry])

        let stale = FinderMenuPresenter.visibleEntries(
            entries: [entry],
            publishStates: [
                config.id.uuidString: ScriptPublishState(
                    entryID: config.id.uuidString,
                    status: .current,
                    fingerprint: "stale"
                ),
            ]
        )
        #expect(stale.isEmpty)

        let failed = FinderMenuPresenter.visibleEntries(
            entries: [entry],
            publishStates: [
                config.id.uuidString: ScriptPublishState(
                    entryID: config.id.uuidString,
                    status: .compileFailed,
                    fingerprint: fingerprint
                ),
            ]
        )
        #expect(failed.isEmpty)
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
        let scriptBackedEntry = MenuEntryScriptPolicy.scriptBackedEntry(for: entry)!

        let visible = FinderMenuPresenter.visibleEntries(
            entries: [entry],
            publishStates: [
                scriptBackedEntry.id: ScriptPublishState(
                    entryID: scriptBackedEntry.id,
                    status: .current,
                    fingerprint: scriptBackedEntry.fingerprint
                ),
            ]
        )

        #expect(visible == [entry])

        let invalidEntry = MenuEntry.composite(
            CompositeMenuItemConfig(
                id: composite.id,
                name: "Invalid",
                steps: []
            )
        )
        let invalidVisible = FinderMenuPresenter.visibleEntries(
            entries: [invalidEntry],
            publishStates: [
                scriptBackedEntry.id: ScriptPublishState(
                    entryID: scriptBackedEntry.id,
                    status: .current,
                    fingerprint: scriptBackedEntry.fingerprint
                ),
            ]
        )
        #expect(invalidVisible.isEmpty)
    }
}
