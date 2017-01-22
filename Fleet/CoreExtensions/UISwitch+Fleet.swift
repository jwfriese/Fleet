import UIKit

extension UISwitch {
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
