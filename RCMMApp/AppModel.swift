import Foundation

@MainActor
final class AppModel {
    let appCoordinator: AppCoordinator
    let appState: AppState

    init(forPreview: Bool = false) {
        appCoordinator = AppCoordinator(forPreview: forPreview)
        appState = AppState(coordinator: appCoordinator, forPreview: forPreview)
    }
}
