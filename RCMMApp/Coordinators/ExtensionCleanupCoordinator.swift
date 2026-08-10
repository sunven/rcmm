import Foundation
import Observation
import RCMMShared
import os.log

enum ExtensionCleanupFlowState: Equatable {
    case idle
    case planning
    case review(ExtensionCleanupPlan)
    case running(ExtensionCleanupStep)
    case finished(ExtensionCleanupResult)
}

/// 编排扩展清理的计划、确认、执行、取消和过期请求处理。
@Observable
@MainActor
final class ExtensionCleanupCoordinator {
    private(set) var state: ExtensionCleanupFlowState

    @ObservationIgnored private(set) var task: Task<Void, Never>?
    private let preparePlan: () async -> ExtensionCleanupPlan
    private let execute: (
        ExtensionCleanupPlan,
        @escaping @Sendable (ExtensionCleanupStep) -> Void
    ) async -> ExtensionCleanupResult
    private let onFinished: () -> Void
    private var planningRequestID: UInt64 = 0
    private var executionRequestID: UInt64 = 0

    private let logger = Logger(
        subsystem: "com.sunven.rcmm",
        category: "extensionCleanup"
    )

    convenience init(
        service: ExtensionCleanupService = ExtensionCleanupService(),
        onFinished: @escaping () -> Void = {}
    ) {
        self.init(
            preparePlan: {
                await Task.detached(priority: .userInitiated) {
                    service.preparePlan(bundle: .main)
                }.value
            },
            execute: { plan, progress in
                await Task.detached(priority: .userInitiated) {
                    service.execute(plan: plan, progress: progress)
                }.value
            },
            onFinished: onFinished
        )
    }

    init(
        initialState: ExtensionCleanupFlowState = .idle,
        preparePlan: @escaping () async -> ExtensionCleanupPlan,
        execute: @escaping (
            ExtensionCleanupPlan,
            @escaping @Sendable (ExtensionCleanupStep) -> Void
        ) async -> ExtensionCleanupResult,
        onFinished: @escaping () -> Void = {}
    ) {
        state = initialState
        self.preparePlan = preparePlan
        self.execute = execute
        self.onFinished = onFinished
    }

    @discardableResult
    func begin() -> Bool {
        guard case .idle = state else { return false }

        planningRequestID &+= 1
        let requestID = planningRequestID
        let preparePlan = self.preparePlan
        state = .planning
        logger.info("开始扫描旧扩展副本 (requestID=\(requestID))")

        task = Task { [weak self] in
            let plan = await preparePlan()
            guard let self else { return }

            guard self.planningRequestID == requestID else {
                self.logger.warning("扫描完成但 requestID 已过期，丢弃结果 (expected=\(requestID), current=\(self.planningRequestID))")
                return
            }
            guard case .planning = self.state else {
                self.logger.warning("扫描完成但状态已不是 planning，丢弃结果 (state=\(String(describing: self.state)))")
                return
            }

            self.state = .review(plan)
        }
        return true
    }

    @discardableResult
    func confirm(plan: ExtensionCleanupPlan) -> Bool {
        guard case .review(let currentPlan) = state else { return false }
        guard currentPlan == plan else { return false }

        executionRequestID &+= 1
        let requestID = executionRequestID
        let execute = self.execute
        let onFinished = self.onFinished
        state = .running(.terminateProcesses)

        task = Task { [weak self] in
            let result = await execute(plan) { [weak self] step in
                Task { @MainActor in
                    guard let self else { return }
                    guard self.executionRequestID == requestID else { return }
                    guard case .running = self.state else { return }
                    self.state = .running(step)
                }
            }
            onFinished()

            guard let self else { return }
            guard self.executionRequestID == requestID else { return }
            guard case .running = self.state else { return }
            self.state = .finished(result)
        }
        return true
    }

    @discardableResult
    func dismiss() -> Bool {
        if case .running = state {
            return false
        }

        planningRequestID &+= 1
        executionRequestID &+= 1
        task?.cancel()
        state = .idle
        return true
    }
}
