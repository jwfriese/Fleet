import UIKit

extension UITextView {
    public func startEditing() -> FleetError? {
        if isFirstResponder {
            return nil
        }
        guard !isHidden else {
            return FleetError(message: "Failed to start editing UITextView: Control is not visible.")
        }
        guard isSelectable else {
            return FleetError(message: "Failed to start editing UITextView: Control is not selectable.")
        }
        guard isEditable else {
            return FleetError(message: "Failed to start editing UITextView: Control is not editable.")
        }
        if let delegate = delegate {
            guard delegate.textViewShouldBeginEditing!(self) else {
                return nil
            }
        }
        guard becomeFirstResponder() else {
            return FleetError(message: "UITextView failed to become first responder. Make sure that the view is a part of the key window's view hierarchy.")
        }

        return nil
    }
}
