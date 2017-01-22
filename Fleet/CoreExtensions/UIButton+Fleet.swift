import UIKit

extension UIButton {

    /**
        Mimics a user tap on the button, firing any associated events
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
