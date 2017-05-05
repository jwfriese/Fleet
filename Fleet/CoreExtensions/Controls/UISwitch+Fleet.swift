import UIKit

extension Fleet {
    enum SwitchError: FleetErrorDefinition {
        case controlUnavailable(message: String)

        var errorMessage: String {
            switch self {
            case .controlUnavailable(let message):
                return "Cannot flip UISwitch: \(message)"
            }
        }

        var name: NSExceptionName { get { return NSExceptionName(rawValue: "Fleet.SwitchError") } }
    }
}

extension UISwitch {
    /**
     Toggles the switch value and fires the appropriate control events.

     - throws:
     A `FleetError` if the switch is hidden, disabled, or if user interaction is disabled.
    */
    public func flip() throws {
        guard isUserInteractionEnabled else {
            FleetError(Fleet.SwitchError.controlUnavailable(message: "View does not allow user interaction.")).raise()
            return
        }
        guard isEnabled else {
            FleetError(Fleet.SwitchError.controlUnavailable(message: "Control is not enabled.")).raise()
            return
        }
        guard !isHidden else {
            FleetError(Fleet.SwitchError.controlUnavailable(message: "Control is not visible.")).raise()
            return
        }

        setOn(!isOn, animated: false)
        sendActions(for: .valueChanged)
        sendActions(for: .touchUpInside)
    }
}
