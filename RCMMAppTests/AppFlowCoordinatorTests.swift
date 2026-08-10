import Foundation
import RCMMShared
import Testing
@testable import rcmm

@Suite("AppFlowCoordinator", .serialized)
@MainActor
struct AppFlowCoordinatorTests {
    @Test("未完成 Onboarding 时启动健康监控并展示窗口")
    func startPresentsOnboardingWhenIncomplete() async {
        var updateCount = 0
        let fixture = makeFixture(
            initialOnboardingCompleted: false,
            onOnboardingCompleted: { updateCount += 1 }
        )

        fixture.flow.start()
        await waitForWindow(.onboarding, in: fixture.window)

        #expect(fixture.healthMonitor.isMonitoring)
        #expect(fixture.window.hasWindow(.onboarding))
        #expect(updateCount == 0)

        fixture.healthMonitor.stopHealthMonitoring()
        fixture.window.dismiss(.onboarding, performCloseEffects: false)
    }

    @Test("已完成 Onboarding 时启动更新调度且不展示窗口")
    func startSchedulesUpdateWhenComplete() {
        var updateCount = 0
        let fixture = makeFixture(
            initialOnboardingCompleted: true,
            onOnboardingCompleted: { updateCount += 1 }
        )

        fixture.flow.start()

        #expect(fixture.healthMonitor.isMonitoring)
        #expect(!fixture.window.hasWindow(.onboarding))
        #expect(updateCount == 1)

        fixture.healthMonitor.stopHealthMonitoring()
    }

    @Test("完成 Onboarding 持久化一次、关闭窗口并只调度一次更新")
    func completeOnboardingPersistsAndSchedulesOnce() {
        var persistedValues: [Bool] = []
        var updateCount = 0
        let fixture = makeFixture(
            initialOnboardingCompleted: false,
            persistOnboardingCompleted: { persistedValues.append($0) },
            onOnboardingCompleted: { updateCount += 1 }
        )
        fixture.flow.showOnboarding()

        fixture.flow.completeOnboarding()
        fixture.flow.completeOnboarding()

        #expect(persistedValues == [true])
        #expect(updateCount == 1)
        #expect(!fixture.window.hasWindow(.onboarding))
    }

    @Test("扩展清理开始时展示窗口，dismiss 后恢复 idle")
    func cleanupWindowTracksCleanupLifecycle() {
        let fixture = makeFixture(initialOnboardingCompleted: true)

        fixture.flow.beginExtensionCleanup()

        #expect(fixture.cleanupCoordinator.state != .idle)
        #expect(fixture.window.hasWindow(.extensionCleanup))

        fixture.flow.dismissExtensionCleanup()

        #expect(fixture.cleanupCoordinator.state == .idle)
        #expect(!fixture.window.hasWindow(.extensionCleanup))
    }

    private func makeFixture(
        initialOnboardingCompleted: Bool,
        persistOnboardingCompleted: @escaping @MainActor (Bool) -> Void = { _ in },
        onOnboardingCompleted: @escaping @MainActor () -> Void = {}
    ) -> Fixture {
        let appCoordinator = AppCoordinator(forPreview: true)
        let applicationDiscovery = ApplicationDiscoveryCoordinator(
            scanApplications: { [] },
            addComposite: { _ in UUID() }
        )
        let healthMonitor = ExtensionHealthMonitor(
            healthReport: {
                ExtensionInstallHealth(
                    status: .enabled,
                    currentExtensionPath: "/Applications/rcmm.app",
                    enabledExtensionPaths: []
                )
            },
            detailMessage: { _ in nil }
        )
        let cleanupCoordinator = ExtensionCleanupCoordinator(
            preparePlan: { Self.cleanupPlan() },
            execute: { _, _ in
                ExtensionCleanupResult.noOp(message: "unused", followUpAdvice: [])
            }
        )
        let windowCoordinator = WindowCoordinator(
            activateAsRegularApp: {},
            hideToMenuBar: {},
            visibleWindows: { [] }
        )
        let flow = AppFlowCoordinator(
            appCoordinator: appCoordinator,
            applicationDiscovery: applicationDiscovery,
            healthMonitor: healthMonitor,
            cleanupCoordinator: cleanupCoordinator,
            windowCoordinator: windowCoordinator,
            initialOnboardingCompleted: initialOnboardingCompleted,
            persistOnboardingCompleted: persistOnboardingCompleted,
            onOnboardingCompleted: onOnboardingCompleted,
            startupDelay: .zero
        )
        return Fixture(
            flow: flow,
            healthMonitor: healthMonitor,
            cleanupCoordinator: cleanupCoordinator,
            window: windowCoordinator
        )
    }

    private func waitForWindow(
        _ destination: AppWindowDestination,
        in coordinator: WindowCoordinator
    ) async {
        for _ in 0..<100 where !coordinator.hasWindow(destination) {
            await Task.yield()
        }
    }

    private static func cleanupPlan() -> ExtensionCleanupPlan {
        let candidate = ExtensionCleanupCandidate(
            appPath: "/tmp/old-rcmm.app",
            extensionPath: "/tmp/old-rcmm.app/Contents/PlugIns/RCMMFinderExtension.appex",
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
private struct Fixture {
    let flow: AppFlowCoordinator
    let healthMonitor: ExtensionHealthMonitor
    let cleanupCoordinator: ExtensionCleanupCoordinator
    let window: WindowCoordinator
}
