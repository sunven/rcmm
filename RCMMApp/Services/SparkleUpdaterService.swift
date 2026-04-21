import AppKit
import Sparkle

@MainActor
final class SparkleUpdaterService {
    private let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func beginInteractiveUpdate() {
        controller.checkForUpdates(nil)
    }
}
