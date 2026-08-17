import Foundation
import Testing
@testable import RCMMShared

/// 状态阶梯的测试。此前 composite 与 New File Menu 各有一份阶梯、custom 没有阶梯，
/// 所以 custom 那一路从来没有被测过 —— 它正是缺陷所在。
@Suite("MenuEntryStatusResolver")
struct MenuEntryStatusResolverTests {
    // MARK: - custom：此前完全没有阶梯的那一路

    @Test("custom 项脚本编译失败时显示同步失败，而不是就绪")
    func customCompileFailureIsVisible() {
        let entry = MenuEntry.custom(MenuEntryCorpus.customApp)
        let status = resolve(
            entry,
            publishStatus: .compileFailed,
            errorSummary: "osacompile 失败"
        )

        #expect(status.kind == .failed)
        #expect(status.text == "同步失败")
        #expect(status.detail == "osacompile 失败")
    }

    @Test("custom 项配置已改但脚本未重编时显示同步中")
    func customStaleFingerprintIsVisible() {
        let entry = MenuEntry.custom(MenuEntryCorpus.customApp)
        let status = resolve(entry, fingerprint: "过期的指纹")

        #expect(status.kind == .syncing)
        #expect(status.text == "同步中")
    }

    @Test("custom 项从未发布时显示同步中")
    func customNeverPublishedIsSyncing() {
        let entry = MenuEntry.custom(MenuEntryCorpus.customApp)
        let status = MenuEntryStatusResolver.status(
            for: entry,
            evaluation: MenuEntryEvaluator.evaluate(entry),
            publishStates: [:]
        )

        #expect(status.kind == .syncing)
    }

    @Test("custom 项名称超长时不可用，而不是就绪")
    func customBlockingValidationErrorIsUnavailable() {
        var config = MenuEntryCorpus.customApp
        config.appName = String(repeating: "长", count: 81)
        let entry = MenuEntry.custom(config)

        // 校验不通过 → 不产出脚本 → Finder 里根本没有这一项。
        #expect(MenuEntryEvaluator.evaluate(entry).scriptBacked.isEmpty)

        let status = MenuEntryStatusResolver.status(
            for: entry,
            evaluation: MenuEntryEvaluator.evaluate(entry),
            publishStates: [:]
        )
        #expect(status.kind == .unavailable)
        #expect(status.text == "不可用")
    }

    @Test("应用不存在时不可用")
    func missingApplicationIsUnavailable() {
        var config = MenuEntryCorpus.customApp
        config.appPath = "/Applications/rcmm-does-not-exist-9f3a2b.app"
        let entry = MenuEntry.custom(config)

        let evaluation = MenuEntryEvaluator.evaluate(entry, environment: .filesystemAware)
        #expect(evaluation.errors.map(\.code) == [.applicationMissing])

        let status = MenuEntryStatusResolver.status(
            for: entry,
            evaluation: evaluation,
            publishStates: [:]
        )
        #expect(status.kind == .unavailable)
    }

    @Test("应用不存在不影响发布门")
    func missingApplicationStillPublishes() {
        var config = MenuEntryCorpus.customApp
        config.appPath = "/Applications/rcmm-does-not-exist-9f3a2b.app"

        // 用户可能只是临时卸载了应用，不该因此丢掉已编译的 .scpt。
        #expect(MenuEntryEvaluator.evaluate(.custom(config)).scriptBacked.count == 1)
    }

    @Test("正常发布的 custom 项就绪")
    func customCurrentIsReady() {
        let entry = MenuEntry.custom(MenuEntryCorpus.customShell)
        let status = resolve(entry)

        #expect(status.kind == .ready)
        #expect(status.text == "就绪")
    }

    // MARK: - 停用与内置

    @Test("停用的条目一律显示已停用", arguments: [
        MenuEntry.custom(MenuEntryCorpus.customDisabled),
        MenuEntry.builtIn(MenuEntryCorpus.builtInDisabled),
    ])
    func disabledEntriesShowDisabled(entry: MenuEntry) {
        let status = MenuEntryStatusResolver.status(
            for: entry,
            evaluation: MenuEntryEvaluator.evaluate(entry),
            publishStates: [:]
        )

        #expect(status.kind == .disabled)
        #expect(status.text == "已停用")
    }

    @Test("Built-in Entry 没有发布状态，停在 system")
    func builtInStopsAtSystem() {
        let entry = MenuEntry.builtIn(MenuEntryCorpus.builtInEnabled)
        let status = MenuEntryStatusResolver.status(
            for: entry,
            evaluation: MenuEntryEvaluator.evaluate(entry),
            publishStates: [:]
        )

        #expect(status.kind == .system)
    }

    // MARK: - composite

    @Test("组合命令有阻塞错误但仍有可执行步骤时为部分可用")
    func compositePartiallyAvailable() {
        let entry = MenuEntry.composite(MenuEntryCorpus.compositePartial)
        let status = resolve(entry)

        #expect(status.kind == .partiallyAvailable)
        #expect(status.text == "部分可用")
    }

    @Test("组合命令一个可执行步骤都没有时不可用")
    func compositeUnavailable() {
        let entry = MenuEntry.composite(MenuEntryCorpus.compositeNoSteps)
        let status = resolve(entry)

        #expect(status.kind == .unavailable)
    }

    @Test("组合命令名称为空但步骤合法时为部分可用")
    func compositeBlankNameIsPartiallyAvailable() {
        // isExecutable=false（无脚本产出）但 hasExecutableChildren=true。
        // 阶梯读的是后者 —— 从 scriptBacked.isEmpty 派生会把这一格错判成不可用。
        let entry = MenuEntry.composite(MenuEntryCorpus.compositeBlankName)
        let evaluation = MenuEntryEvaluator.evaluate(entry)

        #expect(!evaluation.isExecutable)
        #expect(evaluation.hasExecutableChildren)
        #expect(
            MenuEntryStatusResolver.status(
                for: entry,
                evaluation: evaluation,
                publishStates: [:]
            ).kind == .partiallyAvailable
        )
    }

    // MARK: - New File Menu

    @Test("新建菜单没有模板时不可用")
    func newFileNoTemplatesIsUnavailable() {
        let entry = MenuEntry.newFile(MenuEntryCorpus.newFileNoTemplates)
        #expect(resolve(entry).kind == .unavailable)
    }

    @Test("新建菜单模板未全部发布时同步中")
    func newFilePartiallyPublishedIsSyncing() {
        let entry = MenuEntry.newFile(MenuEntryCorpus.newFileValid)
        let evaluation = MenuEntryEvaluator.evaluate(entry)
        #expect(evaluation.scriptBacked.count == 2)

        // 只发布第一个模板。
        let states = Dictionary(
            uniqueKeysWithValues: evaluation.scriptBacked.prefix(1).map {
                ($0.id, ScriptPublishState(entryID: $0.id, status: .current, fingerprint: $0.fingerprint))
            }
        )

        #expect(
            MenuEntryStatusResolver.status(
                for: entry,
                evaluation: evaluation,
                publishStates: states
            ).kind == .syncing
        )
    }

    @Test("新建菜单全部发布后就绪")
    func newFileFullyPublishedIsReady() {
        let entry = MenuEntry.newFile(MenuEntryCorpus.newFileValid)
        #expect(resolve(entry).kind == .ready)
    }

    @Test("模板扩展名不一致只是警告")
    func newFileExtensionMismatchIsWarning() {
        let entry = MenuEntry.newFile(MenuEntryCorpus.newFileMissingTemplateFile)
        let evaluation = MenuEntryEvaluator.evaluate(
            entry,
            probe: MenuEntryFileProbe(
                templateFileInfo: { _ in
                    NewFileTemplateFileInfo(isDirectory: false, pathExtension: "rtf")
                },
                applicationExists: { _ in true }
            )
        )

        #expect(
            MenuEntryStatusResolver.status(
                for: entry,
                evaluation: evaluation,
                publishStates: publishStates(for: evaluation)
            ).kind == .warning
        )
    }

    @Test("模板文件丢失时不可用")
    func newFileMissingTemplateIsUnavailable() {
        let entry = MenuEntry.newFile(MenuEntryCorpus.newFileMissingTemplateFile)
        let evaluation = MenuEntryEvaluator.evaluate(entry, environment: .filesystemAware)

        #expect(
            MenuEntryStatusResolver.status(
                for: entry,
                evaluation: evaluation,
                publishStates: [:]
            ).kind == .unavailable
        )
    }

    @Test("编译失败压过同步中")
    func failureOutranksSyncing() {
        let entry = MenuEntry.newFile(MenuEntryCorpus.newFileValid)
        let evaluation = MenuEntryEvaluator.evaluate(entry)
        var states = publishStates(for: evaluation)
        let failedID = evaluation.scriptBacked[1].id
        states[failedID] = ScriptPublishState(
            entryID: failedID,
            status: .compileFailed,
            fingerprint: evaluation.scriptBacked[1].fingerprint,
            errorSummary: "语法错误"
        )
        states.removeValue(forKey: evaluation.scriptBacked[0].id)

        let status = MenuEntryStatusResolver.status(
            for: entry,
            evaluation: evaluation,
            publishStates: states
        )
        #expect(status.kind == .failed)
        #expect(status.detail == "语法错误")
    }

    // MARK: - Helpers

    private func resolve(
        _ entry: MenuEntry,
        publishStatus: ScriptPublishStatus = .current,
        fingerprint: String? = nil,
        errorSummary: String? = nil
    ) -> MenuEntryStatus {
        let evaluation = MenuEntryEvaluator.evaluate(entry)
        return MenuEntryStatusResolver.status(
            for: entry,
            evaluation: evaluation,
            publishStates: publishStates(
                for: evaluation,
                status: publishStatus,
                fingerprint: fingerprint,
                errorSummary: errorSummary
            )
        )
    }

    private func publishStates(
        for evaluation: MenuEntryEvaluation,
        status: ScriptPublishStatus = .current,
        fingerprint: String? = nil,
        errorSummary: String? = nil
    ) -> [String: ScriptPublishState] {
        Dictionary(
            uniqueKeysWithValues: evaluation.scriptBacked.map { entry in
                (
                    entry.id,
                    ScriptPublishState(
                        entryID: entry.id,
                        status: status,
                        fingerprint: fingerprint ?? entry.fingerprint,
                        errorSummary: errorSummary
                    )
                )
            }
        )
    }
}
