import UIKit

extension UITextField {
    public func enter(text: String) -> FleetError? {
        if let error = startEditing() {
            return error
        }
        if let error = type(text: text) {
            return error
        }
        if let error = stopEditing() {
            return error
        }

        return nil
    }

    public func startEditing() -> FleetError? {
        if isFirstResponder {
            return nil
        }
        guard !isHidden else {
            return FleetError(message: "Failed to start editing UITextField: Control is not visible.")
        }
        guard isEnabled else {
            return FleetError(message: "Failed to start editing UITextField: Control is not enabled.")
        }
        if let delegate = delegate {
            let doesImplementShouldBeginEditing = delegate.responds(to: #selector(UITextFieldDelegate.textFieldShouldBeginEditing(_:)))
            if doesImplementShouldBeginEditing {
                guard delegate.textFieldShouldBeginEditing!(self) else {
                    return nil
                }
            }
        }
        guard becomeFirstResponder() else {
            return FleetError(message: "UITextField failed to become first responder. Make sure that the field is a part of the key window's view hierarchy.")
        }

        return nil
    }

    public func stopEditing() -> FleetError? {
        guard isFirstResponder else {
            return FleetError(message: "Could not stop editing UITextField: Must start editing the text field before you can stop editing it.")
        }
        if let delegate = delegate {
            let doesImplementShouldEndEditing = delegate.responds(to: #selector(UITextFieldDelegate.textFieldShouldEndEditing(_:)))
            if doesImplementShouldEndEditing {
                guard delegate.textFieldShouldEndEditing!(self) else {
                    return nil
                }
            }
        }
        guard resignFirstResponder() else {
            return FleetError(message: "UITextField failed to resign first responder. Make sure that the field is a part of the key window's view hierarchy.")
        }

        return nil
    }

    public func type(text newText: String) -> FleetError? {
        guard isFirstResponder else {
            return FleetError(message: "Could not type text into UITextField: Must start editing the text field before text can be typed into it.")
        }

        for character in newText.characters {
            var existingText = ""
            if let unwrappedText = text {
                existingText = unwrappedText
            }
            if let delegate = delegate {
                let doesImplementShouldChangeText = delegate.responds(to: #selector(UITextFieldDelegate.textField(_:shouldChangeCharactersIn:replacementString:)))
                var doesAllowTextChange = true
                if doesImplementShouldChangeText {
                    doesAllowTextChange = delegate.textField!(self, shouldChangeCharactersIn: NSMakeRange(existingText.characters.count, 0), replacementString: String(character))
                }
                if doesAllowTextChange {
                    existingText += String(character)
                    text = existingText
                }
            } else {
                existingText += String(character)
                text = existingText
            }
        }

        return nil
    }

    public func paste(text textToPaste: String) -> FleetError? {
        guard isFirstResponder else {
            return FleetError(message: "Could not paste text into UITextField: Must start editing the text field before text can be pasted into it.")
        }

        var existingText = ""
        if let unwrappedText = text {
            existingText = unwrappedText
        }
        if let delegate = delegate {
            let doesImplementShouldChangeText = delegate.responds(to: #selector(UITextFieldDelegate.textField(_:shouldChangeCharactersIn:replacementString:)))
            var doesAllowTextChange = true
            if doesImplementShouldChangeText {
                doesAllowTextChange = delegate.textField!(self, shouldChangeCharactersIn: NSMakeRange(existingText.characters.count, 0), replacementString: textToPaste)
            }
            if doesAllowTextChange {
                existingText += textToPaste
                text = existingText
            }
        } else {
            existingText += textToPaste
            text = existingText
        }

        return nil
    }

    public func backspace() -> FleetError? {
        guard isFirstResponder else {
            return FleetError(message: "Could not backspace in UITextField: Must start editing the text field before backspaces can be performed.")
        }

        var existingText = ""
        if let unwrappedText = text {
            existingText = unwrappedText
        }
        if existingText == "" {
            if let delegate = delegate {
                // this still gets called in this case
                let _ = delegate.textField!(self, shouldChangeCharactersIn: NSMakeRange(0, 0), replacementString: "")
            }

            return nil
        }
        if let delegate = delegate {
            let location = existingText.characters.count > 0 ? existingText.characters.count - 1 : 0
            let backspaceAmount = existingText.characters.count > 0 ? 1 : 0
            let doesImplementShouldChangeText = delegate.responds(to: #selector(UITextFieldDelegate.textField(_:shouldChangeCharactersIn:replacementString:)))
            var doesAllowTextChange = true
            if doesImplementShouldChangeText {
                doesAllowTextChange = delegate.textField!(self, shouldChangeCharactersIn: NSMakeRange(location, backspaceAmount), replacementString: "")
            }
            if doesAllowTextChange {
                existingText.remove(at: existingText.index(before: existingText.endIndex))
                text = existingText
            }
        } else {
            existingText.remove(at: existingText.index(before: existingText.endIndex))
            text = existingText
        }

        return nil
    }

    /**
     Clears all text from the text field, firing the textFieldShouldClear?
     event as happens when the user clears the field through the UI.

     If the text field has no delegate, the text is still cleared from the
     field.
     */
    public func clearText() {
        self.text = ""
        if let delegate = delegate {
            let _ = delegate.textFieldShouldClear?(self)
        }
    }
}
