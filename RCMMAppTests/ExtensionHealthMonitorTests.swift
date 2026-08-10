import RCMMShared
import Testing
@testable import rcmm

@Suite("ExtensionHealthMonitor", .serialized)
@MainActor
struct ExtensionHealthMonitorTests {
    @Test("刷新后按扩展状态切换 popover，并保留诊断详情")
    func refreshMapsHealthReportToPresentation() {
        var report = healthReport(status: .enabled)
        let monitor = ExtensionHealthMonitor(
            healthReport: { report },
            detailMessage: { "detail:\($0.status.rawValue)" }
        )

        monitor.refresh()

        #expect(monitor.extensionStatus == .enabled)
        #expect(monitor.extensionStatusDetail == "detail:enabled")
        #expect(monitor.popoverState == .normal)

        report = healthReport(status: .otherInstallationEnabled)
        monitor.refresh()

        #expect(monitor.extensionStatus == .otherInstallationEnabled)
        #expect(monitor.extensionStatusDetail == "detail:otherInstallationEnabled")
        #expect(monitor.popoverState == .healthWarning)
    }

    @Test("禁用状态显示健康警告，未知状态恢复普通 popover")
    func warningAndUnknownStateMapping() {
        var report = healthReport(status: .disabled)
        let monitor = ExtensionHealthMonitor(
            healthReport: { report },
            detailMessage: { _ in nil }
        )

        monitor.refresh()
        #expect(monitor.popoverState == .healthWarning)

        report = healthReport(status: .unknown)
        monitor.refresh()
        #expect(monitor.popoverState == .normal)
    }

    @Test("健康监控可以重复启动和停止")
    func monitoringLifecycle() {
        let monitor = ExtensionHealthMonitor(
            healthReport: { healthReport(status: .enabled) },
            detailMessage: { _ in nil },
            healthCheckInterval: 1800
        )

        #expect(!monitor.isMonitoring)
        monitor.startHealthMonitoring()
        #expect(monitor.isMonitoring)
        monitor.startHealthMonitoring()
        #expect(monitor.isMonitoring)
        monitor.stopHealthMonitoring()
        #expect(!monitor.isMonitoring)
    }

    private func healthReport(status: ExtensionStatus) -> ExtensionInstallHealth {
        ExtensionInstallHealth(
            status: status,
            currentExtensionPath: "/Applications/rcmm.app",
            enabledExtensionPaths: []
        )
    }
}
