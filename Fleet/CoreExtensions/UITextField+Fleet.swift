import UIKit

private var fleet_isFocusedAssociatedKey: UInt = 0

extension UITextField {
    fileprivate var fleet_isFocused: Bool? {
        get {
            let fleet_isFocusedValue = objc_getAssociatedObject(self, &fleet_isFocusedAssociatedKey) as? NSNumber
            return fleet_isFocusedValue?.boolValue
        }

        set {
            var fleet_isFocusedValue: NSNumber?
            if let newValue = newValue {
                fleet_isFocusedValue = NSNumber(value: newValue as Bool)
            }

            objc_setAssociatedObject(self, &fleet_isFocusedAssociatedKey, fleet_isFocusedValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
}

public enum FLTTextFieldError: Error {
    case disabledTextFieldError
}

extension UITextField {
    /**
        Gives the text field focus, firing the .EditingDidBegin events. It
        does not give the text field first responder.

        - Throws: `FLTTextFieldError.DisabledTextFieldError` if the
            text field is disabled.
    */
    public func focus() throws {
        if fleet_isFocused != nil && fleet_isFocused! {
            Logger.logWarning("Attempting to enter a UITextField that was already entered")
            return
        }

        if !isEnabled {
            throw FLTTextFieldError.disabledTextFieldError
        }

        fleet_isFocused = true
        if let delegate = delegate {
            _ = delegate.textFieldShouldBeginEditing?(self)
            _ = delegate.textFieldDidBeginEditing?(self)
        }

        self.sendActions(for: .editingDidBegin)
    }

    /**
        Ends focus in the text field, firing the .EditingDidEnd events. It
        does make the text field resign first responder.
    */
    public func unfocus() {
        if fleet_isFocused == nil || !fleet_isFocused! {
            Logger.logWarning("Attempting to end focus for a UITextField that was never focused")
            return
        }

        if let delegate = delegate {
            _ = delegate.textFieldShouldEndEditing?(self)
            _ = delegate.textFieldDidEndEditing?(self)
        }

        self.sendActions(for: .editingDidEnd)
        fleet_isFocused = false
    }

    /**
        Focuses the text field, enters the given text, and unfocuses it, firing
        the .EditingDidBegin, .EditingChanged, and .EditingDidEnd events
        as appropriate. Does not manipulate first responder.

        If the text field has no delegate, the text is still entered into the
        field and the .EditingChanged event is still fired.

        - Parameter text:   The text to type into the field

        - Throws: `FLTTextFieldError.DisabledTextFieldError` if the
            text field is disabled.
    */
    public func enter(text: String) throws {
        try self.focus()
        self.type(text: text)
        self.unfocus()
    }

    /**
        Types the given text into the text field, firing the .EditingChanged
        event once for each character, as would happen had a real user
        typed the text into the field.

        If the text field has no delegate, the text is still entered into the
        field and the .EditingChanged event is still fired.

        - Parameter text:   The text to type into the field
    */
    public func type(text: String) {
        if fleet_isFocused == nil || !fleet_isFocused! {
            Logger.logWarning("Attempting to type \"\(text)\" into a UITextField that was never focused")
            return
        }

        if let delegate = delegate {
            self.text = ""
            for (index, char) in text.characters.enumerated() {
                _ = delegate.textField?(self, shouldChangeCharactersIn: NSRange.init(location: index, length: 1), replacementString: String(char))
                self.text?.append(char)
                self.sendActions(for: .editingChanged)
            }
        } else {
            self.text = ""
            for (_, char) in text.characters.enumerated() {
                self.text?.append(char)
                self.sendActions(for: .editingChanged)
            }
        }
    }

    /**
        Types the given text into the text field, firing the .EditingChanged
        event just once for the entire string, as would happen had a real user
        pasted the text into the field.

        If the text field has no delegate, the text is still entered into the
        field and the .EditingChanged event is still fired.

        - Parameter text:   The text to paste into the field
    */
    public func paste(text: String) {
        if fleet_isFocused == nil || !fleet_isFocused! {
            Logger.logWarning("Attempting to paste \"\(text)\" into a UITextField that was never focused")
            return
        }

        if let delegate = delegate {
            let length = text.characters.count
            _ = delegate.textField?(self, shouldChangeCharactersIn: NSRange.init(location: 0, length:length), replacementString: text)
        } else {
            self.text = text
        }

        self.sendActions(for: .editingChanged)
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
