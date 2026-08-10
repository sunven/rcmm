import Foundation
import RCMMShared
import Testing
@testable import rcmm

@Suite("AppCoordinator Auto-Repair", .serialized)
@MainActor
struct AppCoordinatorAutoRepairTests {
    @Test("启动时把同步和自动修复合并成一次发布")
    func startupPublishesOnceAndRepairsTypedLoadError() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let item = makeItem(name: "Terminal")
        let error = loadError(scriptID: item.id.uuidString, message: "任意本地化文案")
        harness.configService.saveEntries([.custom(item)])
        harness.errorQueue.upsert(error)

        let coordinator = harness.makeCoordinator(startsServices: true)
        await coordinator.publishTask?.value

        #expect(harness.notifier.postedConfigChangedCount == 1)
        #expect(harness.errorQueue.loadAll().isEmpty)
        #expect(coordinator.autoRepairMessage == "已自动修复脚本文件")
    }

    @Test("打开弹窗摄取晚到的加载错误后触发一次修复")
    func loadingLateErrorTriggersRepair() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let item = makeItem(name: "Terminal")
        harness.configService.saveEntries([.custom(item)])
        let coordinator = harness.makeCoordinator()
        harness.errorQueue.upsert(loadError(scriptID: item.id.uuidString))

        coordinator.loadErrors()
        await coordinator.publishTask?.value

        #expect(harness.notifier.postedConfigChangedCount == 1)
        #expect(harness.errorQueue.loadAll().isEmpty)
    }

    @Test("未分类、非加载和无稳定身份的错误不触发修复")
    func onlyIdentifiedLoadErrorsTriggerRepair() throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let item = makeItem(name: "Terminal")
        harness.configService.saveEntries([.custom(item)])
        let coordinator = harness.makeCoordinator()
        harness.errorQueue.replaceAll(with: [
            ErrorRecord(
                source: "extension",
                message: "脚本文件不存在或无法加载",
                key: scriptKey(item.id.uuidString, kind: .scriptLoad)
            ),
            ErrorRecord(
                source: "extension",
                message: "脚本文件不存在或无法加载",
                key: scriptKey(item.id.uuidString, kind: .scriptExecution),
                kind: .scriptExecution
            ),
            ErrorRecord(
                source: "extension",
                message: "脚本文件不存在或无法加载",
                kind: .scriptLoad
            ),
        ])

        coordinator.loadErrors()

        #expect(coordinator.publishTask == nil)
        #expect(harness.notifier.postedConfigChangedCount == 0)
    }

    @Test("普通编辑发布直接消解已有加载错误而不追加发布")
    func editPublicationAlsoRepairsExistingError() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let item = makeItem(name: "Terminal")
        harness.configService.saveEntries([.custom(item)])
        harness.errorQueue.upsert(loadError(scriptID: item.id.uuidString))
        let coordinator = harness.makeCoordinator()

        coordinator.edit { $0.menuEntries = [.custom(item)] }
        await coordinator.publishTask?.value

        #expect(harness.notifier.postedConfigChangedCount == 1)
        #expect(harness.errorQueue.loadAll().isEmpty)
    }

    @Test("发布在途时摄取加载错误不会追加第二次发布")
    func loadingErrorDuringPublicationDoesNotQueueRepair() async throws {
        let compiler = BlockingAppleScriptCompiler()
        let harness = try PipelineHarness(compiler: compiler)
        defer { harness.cleanup() }
        let item = makeItem(name: "Terminal")
        harness.configService.saveEntries([.custom(item)])
        let coordinator = harness.makeCoordinator(startsServices: true)
        await compiler.waitUntilStarted()
        let error = loadError(scriptID: item.id.uuidString)
        harness.errorQueue.upsert(error)

        coordinator.loadErrors()
        compiler.resume()
        await coordinator.publishTask?.value

        #expect(harness.notifier.postedConfigChangedCount == 1)
        #expect(harness.errorQueue.loadAll().contains { $0.id == error.id })
        #expect(coordinator.autoRepairMessage == nil)
    }

    @Test("配置无脚本时已删除项的错误仍判定修复成功")
    func deletedErrorWithNoScriptsIsSuccessful() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        harness.configService.saveEntries([
            .builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true)),
            .newFile(NewFileMenuConfig(templates: [])),
        ])
        harness.errorQueue.upsert(loadError(scriptID: UUID().uuidString))

        let coordinator = harness.makeCoordinator(startsServices: true)
        await coordinator.publishTask?.value

        #expect(harness.compiler.compiledSources.isEmpty)
        #expect(harness.errorQueue.loadAll().isEmpty)
        #expect(coordinator.autoRepairMessage == "已自动修复脚本文件")
    }

    @Test("部分发布按稳定脚本身份清理成功项和已删除项")
    func partialPublicationClearsOnlyResolvedScriptIDs() async throws {
        let compiler = SelectiveAppleScriptCompiler(failingCalls: [2])
        let harness = try PipelineHarness(compiler: compiler)
        defer { harness.cleanup() }
        let currentItem = makeItem(name: "相同名称")
        let failedItem = makeItem(name: "相同名称")
        let deletedID = UUID().uuidString
        harness.configService.saveEntries([.custom(currentItem), .custom(failedItem)])
        let currentError = loadError(
            scriptID: currentItem.id.uuidString,
            context: "重命名前"
        )
        let failedError = loadError(
            scriptID: failedItem.id.uuidString,
            context: "相同名称"
        )
        let deletedError = loadError(scriptID: deletedID, context: "相同名称")
        harness.errorQueue.replaceAll(with: [currentError, failedError, deletedError])

        let coordinator = harness.makeCoordinator(startsServices: true)
        await coordinator.publishTask?.value

        let remainingLoadErrors = harness.errorQueue.loadAll().filter { $0.kind == .scriptLoad }
        #expect(remainingLoadErrors.map(\.id) == [failedError.id])
        #expect(coordinator.autoRepairMessage == "部分脚本自动修复失败，请打开设置检查")
    }

    @Test("修复失败只在下一次独立摄取时重试")
    func failedRepairRetriesOnNextLoad() async throws {
        let harness = try PipelineHarness(compiler: ThrowingAppleScriptCompiler())
        defer { harness.cleanup() }
        let item = makeItem(name: "Terminal")
        harness.configService.saveEntries([.custom(item)])
        harness.errorQueue.upsert(loadError(scriptID: item.id.uuidString))
        let coordinator = harness.makeCoordinator(startsServices: true)

        await coordinator.publishTask?.value
        #expect(harness.notifier.postedConfigChangedCount == 1)
        #expect(harness.errorQueue.loadAll().contains { $0.kind == .scriptLoad })

        coordinator.loadErrors()
        await coordinator.publishTask?.value

        #expect(harness.notifier.postedConfigChangedCount == 2)
    }

    @Test("发布期间同一脚本产生的新错误不会被旧发布清除")
    func replacementErrorDuringPublicationIsRetained() async throws {
        let compiler = BlockingAppleScriptCompiler()
        let harness = try PipelineHarness(compiler: compiler)
        defer { harness.cleanup() }
        let item = makeItem(name: "Terminal")
        let originalError = loadError(scriptID: item.id.uuidString)
        harness.configService.saveEntries([.custom(item)])
        harness.errorQueue.upsert(originalError)
        let coordinator = harness.makeCoordinator(startsServices: true)
        await compiler.waitUntilStarted()
        let replacementError = loadError(scriptID: item.id.uuidString)
        harness.errorQueue.upsert(replacementError)

        compiler.resume()
        await coordinator.publishTask?.value

        let errors = harness.errorQueue.loadAll()
        #expect(errors.contains { $0.id == replacementError.id })
        #expect(!errors.contains { $0.id == originalError.id })
    }

    @Test("发布期间忽略全部不会在完成时恢复修复提示")
    func dismissDuringPublicationInvalidatesFeedback() async throws {
        let compiler = BlockingAppleScriptCompiler()
        let harness = try PipelineHarness(compiler: compiler)
        defer { harness.cleanup() }
        let item = makeItem(name: "Terminal")
        harness.configService.saveEntries([.custom(item)])
        harness.errorQueue.upsert(loadError(scriptID: item.id.uuidString))
        let coordinator = harness.makeCoordinator(startsServices: true)
        await compiler.waitUntilStarted()

        coordinator.dismissAllErrors()
        compiler.resume()
        await coordinator.publishTask?.value

        #expect(harness.errorQueue.loadAll().isEmpty)
        #expect(coordinator.autoRepairMessage == nil)
    }

    private func makeItem(name: String) -> MenuItemConfig {
        MenuItemConfig(
            appName: name,
            appPath: "/System/Applications/Utilities/Terminal.app"
        )
    }

    private func loadError(
        scriptID: String,
        message: String = "脚本加载失败",
        context: String = "Terminal"
    ) -> ErrorRecord {
        ErrorRecord(
            source: "extension",
            message: message,
            context: context,
            key: scriptKey(scriptID, kind: .scriptLoad),
            kind: .scriptLoad
        )
    }

    private func scriptKey(_ scriptID: String, kind: ErrorRecordKind) -> String {
        "script.\(scriptID).\(kind.rawValue)"
    }
}

private final class SelectiveAppleScriptCompiler: AppleScriptCompiling {
    private let failingCalls: Set<Int>
    private var callCount = 0

    init(failingCalls: Set<Int>) {
        self.failingCalls = failingCalls
    }

    func compile(source: String, outputURL: URL) throws {
        callCount += 1
        if failingCalls.contains(callCount) {
            throw NSError(
                domain: "AppCoordinatorAutoRepairTests",
                code: callCount,
                userInfo: [NSLocalizedDescriptionKey: "compile failed"]
            )
        }
        try Data("compiled".utf8).write(to: outputURL)
    }
}

private final class BlockingAppleScriptCompiler: AppleScriptCompiling, @unchecked Sendable {
    private let lock = NSLock()
    private let started = DispatchSemaphore(value: 0)
    private let release = DispatchSemaphore(value: 0)
    private var hasBlocked = false

    func compile(source: String, outputURL: URL) throws {
        lock.lock()
        let shouldBlock = !hasBlocked
        hasBlocked = true
        lock.unlock()

        if shouldBlock {
            started.signal()
            release.wait()
        }
        try Data("compiled".utf8).write(to: outputURL)
    }

    func waitUntilStarted() async {
        await Task.detached { [started] in
            started.wait()
        }.value
    }

    func resume() {
        release.signal()
    }
}
