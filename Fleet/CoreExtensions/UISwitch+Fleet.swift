import UIKit

extension UISwitch {
    /**
     Toggles the switch value and fires the `.valueChanged` control event.

     - returns:
     A `FleetError` if the switch is hidden or disabled.
    */
    public func flip() -> FleetError? {
        guard isEnabled else {
            return FleetError(message: "Cannot flip UISwitch: Control is not enabled")
        }
        guard !isHidden else {
            return FleetError(message: "Cannot flip UISwitch: Control is not visible")
        }

        setOn(!isOn, animated: false)
        sendActions(for: .valueChanged)
        return nil
    }
}
