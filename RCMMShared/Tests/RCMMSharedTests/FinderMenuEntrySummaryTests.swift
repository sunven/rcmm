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

    @Test("自定义命令生成 command summary")
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
            publishStates: [:],
            appExists: { _ in false }
        )

        #expect(summary.kind == .customCommand)
        #expect(summary.statusKind == .command)
        #expect(summary.statusText == "命令")
        #expect(summary.symbolName == "terminal")
        #expect(summary.allowsDelete == true)
    }

    @Test("缺失应用生成 unavailable summary")
    func missingAppSummary() {
        let config = MenuItemConfig(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            appName: "Missing",
            appPath: "/Applications/Missing.app"
        )

        let summary = FinderMenuEntrySummaryBuilder.summary(
            for: .custom(config),
            position: 1,
            total: 1,
            publishStates: [:],
            appExists: { _ in false }
        )

        #expect(summary.kind == .customApp)
        #expect(summary.statusKind == .unavailable)
        #expect(summary.statusText == "未找到")
        #expect(summary.statusDetail == "/Applications/Missing.app")
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
        let validation = CompositeMenuItemValidator.validate(config)
        let publishState = ScriptPublishState(
            entryID: config.id.uuidString,
            status: .compileFailed,
            fingerprint: validation.fingerprint,
            errorSummary: "compile failed"
        )

        let summary = FinderMenuEntrySummaryBuilder.summary(
            for: .composite(config),
            position: 1,
            total: 1,
            publishStates: [config.id.uuidString: publishState]
        )

        #expect(summary.statusKind == .failed)
        #expect(summary.statusText == "同步失败")
        #expect(summary.statusDetail == "compile failed")
    }

    @Test("新建文件菜单映射 resolver 状态")
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
            publishStates: [:],
            appExists: { _ in true }
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
