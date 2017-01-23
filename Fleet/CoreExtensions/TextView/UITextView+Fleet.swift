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

    public func stopEditing() -> FleetError? {
        guard isFirstResponder else {
            return FleetError(message: "Could not stop editing UITextView: Must start editing the text view before you can stop editing it.")
        }
        if let delegate = delegate {
            guard delegate.textViewShouldEndEditing!(self) else {
                return nil
            }
        }
        guard resignFirstResponder() else {
            return FleetError(message: "UITextView failed to resign first responder. Make sure that the view is a part of the key window's view hierarchy.")
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

    public func paste(text textToPaste: String) -> FleetError? {
        guard isFirstResponder else {
            return FleetError(message: "Could not paste text into UITextView: Must start editing the text view before text can be pasted into it.")
        }

        var existingText = ""
        if let unwrappedText = text {
            existingText = unwrappedText
        }
        if let delegate = delegate {
            let doesAllowTextChange = delegate.textView!(self, shouldChangeTextIn: NSMakeRange(existingText.characters.count, 0), replacementText: textToPaste)
            if doesAllowTextChange {
                delegate.textViewDidChange?(self)
                text.append(textToPaste)
            }
        } else {
            text.append(textToPaste)
        }

        return nil
    }

    public func backspace() -> FleetError? {
        guard isFirstResponder else {
            return FleetError(message: "Could not backspace in UITextView: Must start editing the text view before backspaces can be performed.")
        }

        var existingText = ""
        if let unwrappedText = text {
            existingText = unwrappedText
        }
        if existingText == "" {
            if let delegate = delegate {
                // this still gets called in this case
                let _ = delegate.textView!(self, shouldChangeTextIn: NSMakeRange(0, 0), replacementText: "")
            }

            return nil
        }
        if let delegate = delegate {
            let location = existingText.characters.count > 0 ? existingText.characters.count - 1 : 0
            let backspaceAmount = existingText.characters.count > 0 ? 1 : 0
            let doesAllowTextChange = delegate.textView!(self, shouldChangeTextIn: NSMakeRange(location, backspaceAmount), replacementText: "")
            if doesAllowTextChange {
                delegate.textViewDidChange?(self)
                text.remove(at: text.index(before: text.endIndex))
            }
        } else {
            text.remove(at: text.index(before: text.endIndex))
        }

        return nil
    }
}
