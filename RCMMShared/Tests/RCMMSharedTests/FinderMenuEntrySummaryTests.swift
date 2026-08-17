import Foundation
import Testing
@testable import RCMMShared

@Suite("FinderMenuEntrySummary 测试")
struct FinderMenuEntrySummaryTests {
    @Test("内置菜单生成系统 summary")
    func builtInSummary() {
        let entries: [MenuEntry] = [
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
        ]

        let summary = FinderMenuEntrySummaryBuilder.summaries(
            for: entries,
            publishStates: [:]
        )[0]

        #expect(summary.kind == .builtIn)
        #expect(summary.title == "拷贝路径")
        #expect(summary.typeLabel == "系统")
        #expect(summary.statusKind == .system)
        #expect(summary.allowsDelete == false)
    }

    @Test("自定义命令的徽章是运行状态，类型放在 typeLabel")
    func customCommandSummary() {
        let config = MenuItemConfig(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            appName: "Git Pull",
            appPath: "",
            customCommand: "git pull",
            executionMode: .currentDirectory
        )

        let summary = FinderMenuEntrySummaryBuilder.summary(
            for: .custom(config),
            position: 1,
            total: 1,
            publishStates: [:]
        )

        #expect(summary.kind == .customCommand)
        #expect(summary.typeLabel == "命令")
        // 此前这里恒为「命令」——一个类型标签占着徽章位，脚本有没有发布看不出来。
        #expect(summary.statusKind == .syncing)
        #expect(summary.statusText == "同步中")
        #expect(summary.symbolName == "terminal")
        #expect(summary.allowsDelete == true)
    }

    @Test("应用不存在时为不可用")
    func missingAppSummary() {
        let config = MenuItemConfig(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            appName: "Missing",
            appPath: "/Applications/Missing.app"
        )
        let entry = MenuEntry.custom(config)

        let summary = FinderMenuEntrySummaryBuilder.summary(
            for: entry,
            position: 1,
            total: 1,
            publishStates: [:],
            evaluation: MenuEntryEvaluator.evaluate(
                entry,
                probe: MenuEntryFileProbe(
                    templateFileInfo: { _ in nil },
                    applicationExists: { _ in false }
                )
            )
        )

        #expect(summary.kind == .customApp)
        #expect(summary.statusKind == .unavailable)
        #expect(summary.statusText == "不可用")
        #expect(summary.statusDetail == "找不到应用，它可能已被移动或卸载。")
    }

    @Test("已发布的应用项就绪，detail 给出应用路径")
    func readyAppSummary() {
        let config = MenuItemConfig(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            appName: "Terminal",
            appPath: "/System/Applications/Utilities/Terminal.app"
        )
        let entry = MenuEntry.custom(config)
        let evaluation = MenuEntryEvaluator.evaluate(entry)
        let scriptBackedEntry = evaluation.scriptBacked[0]

        let summary = FinderMenuEntrySummaryBuilder.summary(
            for: entry,
            position: 1,
            total: 1,
            publishStates: [
                scriptBackedEntry.id: ScriptPublishState(
                    entryID: scriptBackedEntry.id,
                    status: .current,
                    fingerprint: scriptBackedEntry.fingerprint
                ),
            ],
            evaluation: evaluation
        )

        #expect(summary.statusKind == .ready)
        #expect(summary.statusText == "就绪")
        #expect(summary.statusDetail == "/System/Applications/Utilities/Terminal.app")
    }

    @Test("应用项编译失败时为同步失败")
    func failedAppSummary() {
        let config = MenuItemConfig(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            appName: "Terminal",
            appPath: "/System/Applications/Utilities/Terminal.app"
        )
        let entry = MenuEntry.custom(config)
        let evaluation = MenuEntryEvaluator.evaluate(entry)
        let scriptBackedEntry = evaluation.scriptBacked[0]

        let summary = FinderMenuEntrySummaryBuilder.summary(
            for: entry,
            position: 1,
            total: 1,
            publishStates: [
                scriptBackedEntry.id: ScriptPublishState(
                    entryID: scriptBackedEntry.id,
                    status: .compileFailed,
                    fingerprint: scriptBackedEntry.fingerprint,
                    errorSummary: "compile failed"
                ),
            ],
            evaluation: evaluation
        )

        // 此前 custom 项完全不读 Publish State，编译失败也显示「就绪」。
        #expect(summary.statusKind == .failed)
        #expect(summary.statusDetail == "compile failed")
    }

    @Test("组合命令无 publish state 时为 syncing")
    func compositeSyncingSummary() {
        let config = makeComposite()

        let summary = FinderMenuEntrySummaryBuilder.summary(
            for: .composite(config),
            position: 1,
            total: 1,
            publishStates: [:]
        )

        #expect(summary.kind == .composite)
        #expect(summary.statusKind == .syncing)
        #expect(summary.statusText == "同步中")
        #expect(summary.subtitle == "1 个步骤")
    }

    @Test("组合命令 publish 编译失败时为 failed")
    func compositeFailedSummary() {
        let config = makeComposite()
        let entry = MenuEntry.composite(config)
        let scriptBackedEntry = MenuEntryEvaluator.evaluate(entry).scriptBacked[0]
        let publishState = ScriptPublishState(
            entryID: scriptBackedEntry.id,
            status: .compileFailed,
            fingerprint: scriptBackedEntry.fingerprint,
            errorSummary: "compile failed"
        )

        let summary = FinderMenuEntrySummaryBuilder.summary(
            for: entry,
            position: 1,
            total: 1,
            publishStates: [scriptBackedEntry.id: publishState]
        )

        #expect(summary.statusKind == .failed)
        #expect(summary.statusText == "同步失败")
        #expect(summary.statusDetail == "compile failed")
    }

    @Test("新建文件菜单走同一条阶梯")
    func newFileSummary() {
        let config = NewFileMenuConfig(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            templates: []
        )

        let summary = FinderMenuEntrySummaryBuilder.summary(
            for: .newFile(config),
            position: 1,
            total: 1,
            publishStates: [:]
        )

        #expect(summary.kind == .newFile)
        #expect(summary.typeLabel == "新建文件")
        #expect(summary.statusKind == .unavailable)
        #expect(summary.statusText == "不可用")
        #expect(summary.allowsDelete == false)
    }

    @Test("停用状态统一映射 disabled")
    func disabledSummary() {
        let config = MenuItemConfig(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            appName: "Terminal",
            appPath: "/System/Applications/Utilities/Terminal.app",
            isEnabled: false
        )

        let summary = FinderMenuEntrySummaryBuilder.summary(
            for: .custom(config),
            position: 1,
            total: 1,
            publishStates: [:]
        )

        #expect(summary.statusKind == .disabled)
        #expect(summary.statusText == "已停用")
    }

    private func makeComposite() -> CompositeMenuItemConfig {
        CompositeMenuItemConfig(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Terminal",
            iconName: "terminal",
            steps: [
                CompositeCommandStep(
                    id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
                    kind: .shell,
                    name: "pwd",
                    commandTemplate: "pwd {path}"
                ),
            ]
        )
    }
}
