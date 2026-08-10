import Foundation
import Observation
import RCMMShared
import os.log

/// 维护 Finder Extension 的健康状态，并按固定间隔刷新。
@Observable
@MainActor
final class ExtensionHealthMonitor {
    var extensionStatus: ExtensionStatus = .unknown
    var extensionStatusDetail: String?
    var popoverState: PopoverState = .normal
    private(set) var isMonitoring = false

    private let healthReport: @MainActor () -> ExtensionInstallHealth
    private let detailMessage: @MainActor (ExtensionInstallHealth) -> String?
    private let activateCurrent: @Sendable () throws -> Void
    private let healthCheckInterval: TimeInterval
    private var healthCheckTimer: Timer?

    private let logger = Logger(
        subsystem: "com.sunven.rcmm",
        category: "extensionHealth"
    )

    init(
        healthReport: @escaping @MainActor () -> ExtensionInstallHealth = { PluginKitService.healthReport() },
        detailMessage: @escaping @MainActor (ExtensionInstallHealth) -> String? = { PluginKitService.detailMessage(for: $0) },
        activateCurrent: @escaping @Sendable () throws -> Void = { try PluginKitService.activateCurrent() },
        healthCheckInterval: TimeInterval = 1800
    ) {
        self.healthReport = healthReport
        self.detailMessage = detailMessage
        self.activateCurrent = activateCurrent
        self.healthCheckInterval = healthCheckInterval
    }

    /// 刷新状态，仅在状态或详情变化时通知观察者。
    func refresh() {
        let report = healthReport()
        let newStatus = report.status
        let newDetail = detailMessage(report)
        let oldStatus = extensionStatus

        guard oldStatus != newStatus || extensionStatusDetail != newDetail else { return }

        extensionStatus = newStatus
        extensionStatusDetail = newDetail

        switch newStatus {
        case .enabled, .unknown:
            popoverState = .normal
        case .otherBuildEnabled, .otherInstallationEnabled, .disabled:
            popoverState = .healthWarning
        }

        logger.info("Extension 状态变化: \(oldStatus.rawValue) → \(newStatus.rawValue), popoverState: \(String(describing: self.popoverState))")
    }

    func activateCurrentFinderExtension() async throws {
        let activateCurrent = self.activateCurrent
        try await Task.detached(priority: .userInitiated) {
            try activateCurrent()
        }.value
        try? await Task.sleep(for: .milliseconds(300))
        refresh()
    }

    func startHealthMonitoring() {
        stopHealthMonitoring()
        healthCheckTimer = Timer.scheduledTimer(
            withTimeInterval: healthCheckInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        isMonitoring = true
    }

    func stopHealthMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        isMonitoring = false
    }
}
