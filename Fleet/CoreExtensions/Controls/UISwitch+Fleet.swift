import UIKit

extension Fleet {
    public enum SwitchError: Error, CustomStringConvertible {
        case controlUnavailable(message: String)

        public var description: String {
            switch self {
            case .controlUnavailable(let message):
                return "Cannot flip UISwitch: \(message)"
            }
        }
    }
}

extension UISwitch {
    /**
     Toggles the switch value and fires the appropriate control events.

     - throws:
     A `Fleet.SwitchError` if the switch is hidden, disabled, or if user interaction is disabled.
    */
    public func flip() throws {
        guard isUserInteractionEnabled else {
            throw Fleet.SwitchError.controlUnavailable(message: "View does not allow user interaction.")
        }
        guard isEnabled else {
            throw Fleet.SwitchError.controlUnavailable(message: "Control is not enabled.")
        }
        guard !isHidden else {
            throw Fleet.SwitchError.controlUnavailable(message: "Control is not visible.")
        }

        setOn(!isOn, animated: false)
        sendActions(for: .valueChanged)
        sendActions(for: .touchUpInside)
    }
}
