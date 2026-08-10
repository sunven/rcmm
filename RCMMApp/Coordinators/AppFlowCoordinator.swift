import Observation
import RCMMShared
import SwiftUI

/// 编排应用启动、Onboarding 完成状态与扩展清理窗口。
@Observable
@MainActor
final class AppFlowCoordinator {
    private let appCoordinator: AppCoordinator
    private let applicationDiscovery: ApplicationDiscoveryCoordinator
    private let healthMonitor: ExtensionHealthMonitor
    private let cleanupCoordinator: ExtensionCleanupCoordinator
    private let windowCoordinator: WindowCoordinator
    private let persistOnboardingCompleted: @MainActor (Bool) -> Void
    private let onOnboardingCompleted: @MainActor () -> Void
    private let startupDelay: Duration
    private var isOnboardingCompleted: Bool
    @ObservationIgnored private var startupTask: Task<Void, Never>?

    convenience init(
        appCoordinator: AppCoordinator,
        applicationDiscovery: ApplicationDiscoveryCoordinator,
        healthMonitor: ExtensionHealthMonitor,
        cleanupCoordinator: ExtensionCleanupCoordinator,
        windowCoordinator: WindowCoordinator,
        onOnboardingCompleted: @escaping @MainActor () -> Void
    ) {
        let preferences = SharedPreferencesStore()
        self.init(
            appCoordinator: appCoordinator,
            applicationDiscovery: applicationDiscovery,
            healthMonitor: healthMonitor,
            cleanupCoordinator: cleanupCoordinator,
            windowCoordinator: windowCoordinator,
            initialOnboardingCompleted: preferences.bool(forKey: SharedKeys.onboardingCompleted),
            persistOnboardingCompleted: {
                preferences.set($0, forKey: SharedKeys.onboardingCompleted)
            },
            onOnboardingCompleted: onOnboardingCompleted,
            startupDelay: .milliseconds(300)
        )
    }

    init(
        appCoordinator: AppCoordinator,
        applicationDiscovery: ApplicationDiscoveryCoordinator,
        healthMonitor: ExtensionHealthMonitor,
        cleanupCoordinator: ExtensionCleanupCoordinator,
        windowCoordinator: WindowCoordinator,
        initialOnboardingCompleted: Bool,
        persistOnboardingCompleted: @escaping @MainActor (Bool) -> Void,
        onOnboardingCompleted: @escaping @MainActor () -> Void,
        startupDelay: Duration = .milliseconds(300)
    ) {
        self.appCoordinator = appCoordinator
        self.applicationDiscovery = applicationDiscovery
        self.healthMonitor = healthMonitor
        self.cleanupCoordinator = cleanupCoordinator
        self.windowCoordinator = windowCoordinator
        self.isOnboardingCompleted = initialOnboardingCompleted
        self.persistOnboardingCompleted = persistOnboardingCompleted
        self.onOnboardingCompleted = onOnboardingCompleted
        self.startupDelay = startupDelay
    }

    func start() {
        healthMonitor.refresh()
        healthMonitor.startHealthMonitoring()

        if isOnboardingCompleted {
            onOnboardingCompleted()
        } else {
            startupTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: self.startupDelay)
                self.showOnboardingIfNeeded()
            }
        }
    }

    func showOnboardingIfNeeded() {
        guard !isOnboardingCompleted else { return }
        showOnboarding()
    }

    func showOnboarding() {
        let contentView = OnboardingFlowView()
            .environment(self)
            .environment(appCoordinator)
            .environment(appCoordinator.configStore)
            .environment(applicationDiscovery)

        windowCoordinator.present(.onboarding, content: contentView) { _ in
            true
        }
    }

    func completeOnboarding() {
        let shouldScheduleUpdate = !isOnboardingCompleted
        if shouldScheduleUpdate {
            isOnboardingCompleted = true
            persistOnboardingCompleted(true)
        }
        windowCoordinator.dismiss(.onboarding)
        if shouldScheduleUpdate {
            onOnboardingCompleted()
        }
    }

    func beginExtensionCleanup() {
        if windowCoordinator.hasWindow(.extensionCleanup) {
            showExtensionCleanupWindow()
            return
        }
        guard cleanupCoordinator.begin() else { return }
        showExtensionCleanupWindow()
    }

    func dismissExtensionCleanup() {
        guard cleanupCoordinator.dismiss() else { return }
        windowCoordinator.dismiss(.extensionCleanup)
    }

    private func showExtensionCleanupWindow() {
        let contentView = ExtensionCleanupSheet(onDismiss: { [weak self] in
            self?.dismissExtensionCleanup()
        })
        .environment(cleanupCoordinator)

        windowCoordinator.present(.extensionCleanup, content: contentView) { [weak self] _ in
            _ = self?.cleanupCoordinator.dismiss()
            return true
        }
    }
}
