import Foundation

public enum UpdateInstallEligibility: Equatable, Sendable {
    case inPlaceInstall
    case manualInstall(reason: String, fallbackURL: URL)
}
