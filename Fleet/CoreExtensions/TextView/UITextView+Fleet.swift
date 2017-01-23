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

    public func type(text newText: String) -> FleetError? {
        guard isFirstResponder else {
            return FleetError(message: "Could not type text into UITextView: Must start editing the text view before text can be typed into it.")
        }

        for character in newText.characters {
            var existingText = ""
            if let unwrappedText = text {
                existingText = unwrappedText
            }
            if let delegate = delegate {
                let doesAllowTextChange = delegate.textView!(self, shouldChangeTextIn: NSMakeRange(existingText.characters.count, 0), replacementText: String(character))
                if doesAllowTextChange {
                    delegate.textViewDidChange?(self)
                    text.append(character)
                }
            } else {
                text.append(character)
            }
        }

        return nil
    }
}
