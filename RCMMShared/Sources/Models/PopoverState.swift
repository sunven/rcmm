import Foundation

public enum PopoverState: Sendable {
    case normal
    case healthWarning
    case onboarding

    public var preferredPopoverWidth: Double {
        switch self {
        case .healthWarning:
            return 360
        case .normal, .onboarding:
            return 260
        }
    }
}
