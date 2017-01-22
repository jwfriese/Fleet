import UIKit

extension UIButton {

    /**
     Mimics a user tap on the button, firing the `.touchUpInside` control event.

     - returns:
     A `FleetError` if the button is hidden or disabled.
     */
    public func tap() -> FleetError? {
        guard isEnabled else {
            return FleetError(message: "Cannot tap UIButton: Control is not enabled")
        }
        guard !isHidden else {
            return FleetError(message: "Cannot tap UIButton: Control is not visible")
        }

        sendActions(for: .touchUpInside)
        return nil
    }
}
