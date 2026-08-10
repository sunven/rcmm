import Foundation

@MainActor
final class AppModel {
    let appCoordinator: AppCoordinator
    let applicationDiscoveryCoordinator: ApplicationDiscoveryCoordinator
    let extensionHealthMonitor: ExtensionHealthMonitor
    let extensionCleanupCoordinator: ExtensionCleanupCoordinator
    let windowCoordinator: WindowCoordinator
    let updateCoordinator: UpdateCoordinator
    let appFlowCoordinator: AppFlowCoordinator

    init(forPreview: Bool = false) {
        if !forPreview {
            ConfigurationMigrationService().migrateIfNeeded()
        }

        let appCoordinator = AppCoordinator(forPreview: forPreview)
        self.appCoordinator = appCoordinator
        let applicationDiscoveryCoordinator = ApplicationDiscoveryCoordinator(
            addComposite: { composite in
                appCoordinator.edit { $0.addCompositeCommand(composite) }
            }
        )
        self.applicationDiscoveryCoordinator = applicationDiscoveryCoordinator

        let extensionHealthMonitor = ExtensionHealthMonitor()
        self.extensionHealthMonitor = extensionHealthMonitor
        let extensionCleanupCoordinator = ExtensionCleanupCoordinator(
            onFinished: { extensionHealthMonitor.refresh() }
        )
        self.extensionCleanupCoordinator = extensionCleanupCoordinator
        let windowCoordinator = WindowCoordinator()
        self.windowCoordinator = windowCoordinator
        let updateCoordinator = UpdateCoordinator(
            windowCoordinator: windowCoordinator,
            forPreview: forPreview
        )
        self.updateCoordinator = updateCoordinator
        let onOnboardingCompleted = {
            updateCoordinator.scheduleStartupCheckIfNeeded()
        }
        let appFlowCoordinator: AppFlowCoordinator
        if forPreview {
            appFlowCoordinator = AppFlowCoordinator(
                appCoordinator: appCoordinator,
                applicationDiscovery: applicationDiscoveryCoordinator,
                healthMonitor: extensionHealthMonitor,
                cleanupCoordinator: extensionCleanupCoordinator,
                windowCoordinator: windowCoordinator,
                initialOnboardingCompleted: false,
                persistOnboardingCompleted: { _ in },
                onOnboardingCompleted: onOnboardingCompleted
            )
        } else {
            appFlowCoordinator = AppFlowCoordinator(
                appCoordinator: appCoordinator,
                applicationDiscovery: applicationDiscoveryCoordinator,
                healthMonitor: extensionHealthMonitor,
                cleanupCoordinator: extensionCleanupCoordinator,
                windowCoordinator: windowCoordinator,
                onOnboardingCompleted: onOnboardingCompleted
            )
        }
        self.appFlowCoordinator = appFlowCoordinator

        if !forPreview {
            appFlowCoordinator.start()
        }
    }
}
