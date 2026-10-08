import Foundation
import RCMMShared
import Testing
@testable import rcmm

@Suite("Onboarding verification", .serialized)
@MainActor
struct OnboardingVerificationTests {
    private let terminal = AppInfo(
        name: "Terminal",
        bundleId: "com.apple.Terminal",
        path: "/System/Applications/Utilities/Terminal.app",
        category: .terminal
    )

    private func makeCoordinator(in harness: PipelineHarness) -> AppCoordinator {
        harness.configService.saveEntries([.builtIn(BuiltInMenuItem(type: .copyPath, isEnabled: true))])
        return harness.makeCoordinator()
    }

    @Test("验证前落盘，同步和手动确认都是完成条件")
    func persistsBeforeVerification() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(in: harness)
        let verification = OnboardingVerification()

        #expect(!AppPickerItemMatcher.isAlreadyAdded(terminal, in: harness.configService.loadEntries()))
        verification.prepare(apps: [terminal], coordinator: coordinator)
        #expect(AppPickerItemMatcher.isAlreadyAdded(terminal, in: harness.configService.loadEntries()))
        #expect(verification.phase == .syncing)
        verification.confirm(true, in: coordinator.configStore)
        #expect(!verification.isConfirmed(in: coordinator.configStore))

        await verification.task?.value
        #expect(verification.isReady(in: coordinator.configStore))
        #expect(!verification.isConfirmed(in: coordinator.configStore))
        verification.confirm(true, in: coordinator.configStore)
        #expect(verification.isConfirmed(in: coordinator.configStore))
        #expect(harness.notifier.postedConfigChangedCount == 1)
    }

    @Test("重复点击不重复发布，返回继续保留条目且不重复添加")
    func repeatedPreparation() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(in: harness)
        let verification = OnboardingVerification()
        verification.prepare(apps: [terminal, terminal], coordinator: coordinator)
        verification.prepare(apps: [terminal], coordinator: coordinator)
        await verification.task?.value
        #expect(harness.notifier.postedConfigChangedCount == 1)
        let original = coordinator.configStore.menuEntries

        verification.confirm(true, in: coordinator.configStore)
        verification.leave()
        #expect(!verification.isConfirmed(in: coordinator.configStore))
        verification.prepare(apps: [terminal], coordinator: coordinator)
        await verification.task?.value
        #expect(coordinator.configStore.menuEntries == original)
        #expect(verification.targets.count == 1)
        #expect(verification.isReady(in: coordinator.configStore))
        #expect(!verification.isConfirmed(in: coordinator.configStore))
    }

    @Test("离开向导使等待结果失效，但保留已提交配置与发布")
    func leavingDuringPublication() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(in: harness)
        let verification = OnboardingVerification()
        verification.prepare(apps: [terminal], coordinator: coordinator)
        let previousTask = verification.task
        verification.leave()
        await previousTask?.value
        await coordinator.waitForCurrentPublication()

        #expect(verification.phase == .idle)
        #expect(!verification.isConfirmed(in: coordinator.configStore))
        #expect(AppPickerItemMatcher.isAlreadyAdded(terminal, in: harness.configService.loadEntries()))
        #expect(harness.notifier.postedConfigChangedCount == 1)

        verification.prepare(apps: [], coordinator: coordinator)
        await verification.task?.value
        #expect(verification.isReady(in: coordinator.configStore))
    }

    @Test("同步失败阻止确认，重试后可以验证且不添加条目")
    func failureAndRetry() async throws {
        let compiler = OnboardingRetryCompiler()
        let harness = try PipelineHarness(compiler: compiler)
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(in: harness)
        let verification = OnboardingVerification()
        verification.prepare(apps: [terminal], coordinator: coordinator)
        await verification.task?.value
        let entries = coordinator.configStore.menuEntries
        #expect(verification.phase == .finished)
        #expect(!verification.isReady(in: coordinator.configStore))
        #expect(verification.items(in: coordinator.configStore).first?.issue != nil)
        verification.confirm(true, in: coordinator.configStore)
        #expect(!verification.isConfirmed(in: coordinator.configStore))

        compiler.allowSuccess()
        verification.retry(coordinator: coordinator)
        await verification.task?.value
        #expect(verification.isReady(in: coordinator.configStore))
        #expect(!verification.isConfirmed(in: coordinator.configStore))
        #expect(coordinator.configStore.menuEntries == entries)
        #expect(harness.notifier.postedConfigChangedCount == 2)
    }

    @Test("缺失和过期发布状态均不能完成，无关错误不阻塞验证")
    func publicationValidity() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(in: harness)
        let verification = OnboardingVerification()
        verification.prepare(apps: [terminal], coordinator: coordinator)
        await verification.task?.value
        let id = try #require(verification.targets.first?.id)
        let state = try #require(coordinator.configStore.scriptPublishStates[id])
        verification.confirm(true, in: coordinator.configStore)
        coordinator.configStore.scriptPublishStates.removeValue(forKey: id)
        #expect(!verification.isReady(in: coordinator.configStore))
        #expect(!verification.isConfirmed(in: coordinator.configStore))
        var stale = state
        stale.fingerprint = "old configuration"
        coordinator.configStore.scriptPublishStates[id] = stale
        #expect(!verification.isReady(in: coordinator.configStore))
        coordinator.configStore.scriptPublishStates[id] = state
        coordinator.configStore.scriptPublishStates["unrelated"] = ScriptPublishState(
            entryID: "unrelated", status: .compileFailed, fingerprint: "unrelated"
        )
        #expect(verification.isReady(in: coordinator.configStore))
        verification.retry(coordinator: coordinator)
        #expect(!verification.isConfirmed(in: coordinator.configStore))
        await verification.task?.value
        #expect(!verification.isConfirmed(in: coordinator.configStore))
    }

    @Test("目标变更、停用或删除不能沿用先前确认")
    func targetChangesInvalidateConfirmation() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(in: harness)
        let store = coordinator.configStore
        let verification = OnboardingVerification()
        verification.prepare(apps: [terminal], coordinator: coordinator)
        await verification.task?.value
        verification.confirm(true, in: store)
        let id = try #require(verification.targets.first?.id)
        let index = try #require(store.menuEntries.firstIndex { $0.id == id })
        guard case .custom(var config) = store.menuEntries[index] else {
            Issue.record("Expected application entry")
            return
        }
        config.appName = "Renamed Terminal"
        store.menuEntries[index] = .custom(config)
        #expect(!verification.isConfirmed(in: store))
        config.isEnabled = false
        store.menuEntries[index] = .custom(config)
        #expect(!verification.isReady(in: store))
        store.menuEntries.remove(at: index)
        #expect(!verification.isReady(in: store))
        #expect(verification.items(in: store).first?.issue?.contains("已删除") == true)
    }

    @Test("重开向导使用首个已有应用，不覆盖自定义配置")
    func existingConfiguration() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(in: harness)
        let existing = MenuItemConfig(
            appName: "My Terminal", bundleId: terminal.bundleId, appPath: terminal.path,
            customCommand: "open -a {app} {path}"
        )
        coordinator.edit { $0.menuEntries = [.custom(existing)] }
        await coordinator.waitForCurrentPublication()
        let verification = OnboardingVerification()
        verification.prepare(apps: [], coordinator: coordinator)
        await verification.task?.value
        #expect(verification.targets.map(\.id) == [existing.id.uuidString])
        #expect(coordinator.configStore.menuEntries == [.custom(existing)])
        #expect(verification.isReady(in: coordinator.configStore))
    }

    @Test("没有应用不能用内置菜单代替验证")
    func noApplication() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(in: harness)
        #expect(OnboardingVerification.existingApplication(in: coordinator.configStore.menuEntries) == nil)
        let verification = OnboardingVerification()
        verification.prepare(apps: [], coordinator: coordinator)
        await verification.task?.value
        #expect(!verification.isReady(in: coordinator.configStore))
    }

    @Test("目标删除后返回重新添加，可以重新验证")
    func replacingDeletedTarget() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(in: harness)
        let verification = OnboardingVerification()
        verification.prepare(apps: [terminal], coordinator: coordinator)
        await verification.task?.value
        let oldID = try #require(verification.targets.first?.id)
        coordinator.edit { $0.menuEntries.removeAll { $0.id == oldID } }
        await coordinator.waitForCurrentPublication()
        verification.leave()
        verification.prepare(apps: [terminal], coordinator: coordinator)
        await verification.task?.value
        #expect(verification.targets.count == 1)
        #expect(verification.targets.first?.id != oldID)
        #expect(verification.isReady(in: coordinator.configStore))
    }

    @Test("所有新增应用都须同步，不能用一个成功项掩盖另一个失败项")
    func allSelectedApplicationsMustBeCurrent() async throws {
        let harness = try PipelineHarness()
        defer { harness.cleanup() }
        let coordinator = makeCoordinator(in: harness)
        let verification = OnboardingVerification()
        let textEdit = AppInfo(name: "TextEdit", bundleId: "com.apple.TextEdit", path: "/System/Applications/TextEdit.app")
        verification.prepare(apps: [terminal, textEdit], coordinator: coordinator)
        await verification.task?.value
        #expect(verification.isReady(in: coordinator.configStore))
        let secondID = try #require(verification.targets.last?.id)
        coordinator.configStore.scriptPublishStates.removeValue(forKey: secondID)
        #expect(verification.items(in: coordinator.configStore).first?.issue == nil)
        #expect(!verification.isReady(in: coordinator.configStore))
    }
}

private final class OnboardingRetryCompiler: AppleScriptCompiling {
    private let lock = NSLock()
    private var shouldFail = true

    func allowSuccess() {
        lock.lock()
        defer { lock.unlock() }
        shouldFail = false
    }

    func compile(source: String, outputURL: URL) throws {
        lock.lock()
        let fails = shouldFail
        lock.unlock()
        if fails {
            throw NSError(domain: "OnboardingTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "compile failed"])
        }
        try Data("compiled".utf8).write(to: outputURL)
    }
}
