import UIKit

extension Fleet {
    enum ButtonError: FleetErrorDefinition {
        case controlUnavailable(String)

        var errorMessage: String {
            switch self {
            case .controlUnavailable(let message):
                return "Cannot tap UIButton: \(message)"
            }
        }

        var name: NSExceptionName { get { return NSExceptionName("Fleet.ButtonError") } }
    }
}

extension UIButton {

    /**
     Mimics a user tap on the button, firing all appropriate control events.

     - throws:
     A `FleetError` if the button is hidden, disabled, or does not allow user interaction.
     */
    public func tap() throws {
        if !isUserInteractionEnabled {
            FleetError(Fleet.ButtonError.controlUnavailable("View does not allow user interaction.")).raise()
            return
        }
        guard isEnabled else {
            FleetError(Fleet.ButtonError.controlUnavailable("Control is not enabled.")).raise()
            return
        }
        guard !isHidden else {
            FleetError(Fleet.ButtonError.controlUnavailable("Control is not visible.")).raise()
            return
        }

        sendActions(for: .touchDown)
        sendActions(for: .touchUpInside)
    }
}
