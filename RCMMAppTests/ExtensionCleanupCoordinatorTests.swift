import RCMMShared
import Testing
@testable import rcmm

@Suite("ExtensionCleanupCoordinator", .serialized)
@MainActor
struct ExtensionCleanupCoordinatorTests {
    @Test("begin 从 planning 进入 review，重复开始被拒绝")
    func beginBuildsPlanOnce() async {
        let plan = cleanupPlan(path: "/tmp/old-rcmm.app")
        var prepareCount = 0
        let coordinator = makeCoordinator(
            preparePlan: {
                prepareCount += 1
                return plan
            }
        )

        #expect(coordinator.begin())
        #expect(coordinator.state == .planning)
        #expect(!coordinator.begin())
        await coordinator.task?.value

        #expect(coordinator.state == .review(plan))
        #expect(prepareCount == 1)
    }

    @Test("dismiss 使晚到的扫描结果失效")
    func dismissalInvalidatesLatePlan() async {
        let plan = cleanupPlan(path: "/tmp/late-rcmm.app")
        let provider = SuspendedValue<ExtensionCleanupPlan>()
        let coordinator = makeCoordinator(
            preparePlan: { await provider.value() }
        )

        #expect(coordinator.begin())
        let planningTask = coordinator.task
        await provider.waitUntilRequested()
        #expect(coordinator.dismiss())
        provider.resume(returning: plan)
        await planningTask?.value

        #expect(coordinator.state == .idle)
    }

    @Test("只执行当前 review 的计划，并在完成后回调")
    func confirmExecutesReviewedPlan() async {
        let plan = cleanupPlan(path: "/tmp/current-rcmm.app")
        let otherPlan = cleanupPlan(path: "/tmp/other-rcmm.app")
        let result = ExtensionCleanupResult.noOp(message: "done", followUpAdvice: [])
        let executor = SuspendedValue<ExtensionCleanupResult>()
        var finishedCount = 0
        var executedPlans: [ExtensionCleanupPlan] = []
        let coordinator = ExtensionCleanupCoordinator(
            preparePlan: { plan },
            execute: { plan, progress in
                executedPlans.append(plan)
                progress(.deleteApps)
                return await executor.value()
            },
            onFinished: { finishedCount += 1 }
        )

        #expect(coordinator.begin())
        await coordinator.task?.value
        #expect(!coordinator.confirm(plan: otherPlan))
        #expect(coordinator.confirm(plan: plan))
        let executionTask = coordinator.task
        await executor.waitUntilRequested()
        await Task.yield()

        #expect(coordinator.state == .running(.deleteApps))

        executor.resume(returning: result)
        await executionTask?.value

        #expect(coordinator.state == .finished(result))
        #expect(executedPlans == [plan])
        #expect(finishedCount == 1)
        #expect(coordinator.dismiss())
        #expect(coordinator.state == .idle)
    }

    @Test("running 期间不能 dismiss")
    func runningCannotBeDismissed() async {
        let plan = cleanupPlan(path: "/tmp/running-rcmm.app")
        let result = ExtensionCleanupResult.noOp(message: "done", followUpAdvice: [])
        let executor = SuspendedValue<ExtensionCleanupResult>()
        let coordinator = ExtensionCleanupCoordinator(
            preparePlan: { plan },
            execute: { _, _ in await executor.value() }
        )

        #expect(coordinator.begin())
        await coordinator.task?.value
        #expect(coordinator.confirm(plan: plan))
        let executionTask = coordinator.task
        await executor.waitUntilRequested()

        #expect(coordinator.state == .running(.terminateProcesses))
        #expect(!coordinator.dismiss())

        executor.resume(returning: result)
        await executionTask?.value
        #expect(coordinator.state == .finished(result))
    }

    private func makeCoordinator(
        preparePlan: @escaping () async -> ExtensionCleanupPlan
    ) -> ExtensionCleanupCoordinator {
        ExtensionCleanupCoordinator(
            preparePlan: preparePlan,
            execute: { _, _ in
                ExtensionCleanupResult.noOp(message: "unused", followUpAdvice: [])
            }
        )
    }

    private func cleanupPlan(path: String) -> ExtensionCleanupPlan {
        let candidate = ExtensionCleanupCandidate(
            appPath: path,
            extensionPath: "\(path)/Contents/PlugIns/RCMMFinderExtension.appex",
            source: .derivedData,
            disposition: .delete,
            skipReason: nil
        )!
        return ExtensionCleanupPlan(
            currentAppPath: "/Applications/rcmm.app",
            deleteCandidates: [candidate],
            skippedCandidates: [],
            processesToTerminate: [],
            postCleanupCommands: []
        )!
    }
}

@MainActor
private final class SuspendedValue<Value> {
    private var continuation: CheckedContinuation<Value, Never>?

    func value() async -> Value {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitUntilRequested() async {
        while continuation == nil {
            await Task.yield()
        }
    }

    func resume(returning value: Value) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}
