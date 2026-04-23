import Foundation

public enum PopoverState: Sendable {
    case normal
    case healthWarning
    case onboarding

    public var preferredPopoverWidth: Double {
        switch self {
        case .healthWarning:
            return 340
        case .normal, .onboarding:
            return 220
        }
    }
}
