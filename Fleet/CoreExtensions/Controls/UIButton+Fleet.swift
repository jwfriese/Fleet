import UIKit

extension Fleet {
    public enum ButtonError: Error {
        case controlUnavailable(String)

        public var description: String {
            switch self {
            case .controlUnavailable(let message):
                return "Cannot tap UIButton: \(message)"
            }
        }
    }
}

extension UIButton {

    /**
     Mimics a user tap on the button, firing all appropriate control events.

     - throws:
     A `Fleet.ButtonError` if the button is hidden, disabled, or does not allow user interaction.
     */
    public func tap() throws {
        if !isUserInteractionEnabled {
            throw Fleet.TextViewError.controlUnavailable("View does not allow user interaction.")
        }
        guard isEnabled else {
            throw Fleet.ButtonError.controlUnavailable("Control is not enabled.")
        }
        guard !isHidden else {
            throw Fleet.ButtonError.controlUnavailable("Control is not visible.")
        }

        sendActions(for: .touchDown)
        sendActions(for: .touchUpInside)
    }
}
