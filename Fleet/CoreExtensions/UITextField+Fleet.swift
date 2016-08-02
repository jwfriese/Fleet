import UIKit

private var isFocusedAssociatedKey: UInt = 0

extension UITextField {
    private var isFocused: Bool? {
        get {
            let isFocusedValue = objc_getAssociatedObject(self, &isFocusedAssociatedKey) as? NSNumber
            return isFocusedValue?.boolValue
        }

        set {
            var isFocusedValue: NSNumber?
            if let newValue = newValue {
                isFocusedValue = NSNumber(bool: newValue)
            }
            
            objc_setAssociatedObject(self, &isFocusedAssociatedKey, isFocusedValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
}

public enum FLTTextFieldError: ErrorType {
    case DisabledTextFieldError
}

extension UITextField {
    /**
        Enters the text field, firing the .EditingDidBegin events. It
        does not give the text field first responder.

        - Throws: `FLTTextFieldError.DisabledTextFieldError` if the
            text field is disabled.
    */
    public func enter() throws {
        if isFocused != nil && isFocused! {
            Logger.logWarning("Attempting to enter a UITextField that was already entered")
            return
        }

        if !enabled {
            throw FLTTextFieldError.DisabledTextFieldError
        }

        isFocused = true
        if let delegate = delegate {
            _ = delegate.textFieldShouldBeginEditing?(self)
            _ = delegate.textFieldDidBeginEditing?(self)
        }

        self.sendActionsForControlEvents(.EditingDidBegin)
    }

    /**
        Enters the text field, firing the .EditingDidEnd events. It
        does make the text field resign first responder.
    */
    public func leave() {
        if isFocused == nil || !isFocused! {
            Logger.logWarning("Attempting to leave a UITextField that was never entered")
            return
        }

        if let delegate = delegate {
            _ = delegate.textFieldShouldEndEditing?(self)
            _ = delegate.textFieldDidEndEditing?(self)
        }

        self.sendActionsForControlEvents(.EditingDidEnd)
        isFocused = false
    }

    /**
        Enters the text field, enters the given text, and leaves it, firing
        the .EditingDidBegin, .EditingChanged, and .EditingDidEnd events
        as appropriate. Does not manipulate first responder.

        If the text field has no delegate, the text is still entered into the
        field and the .EditingChanged event is still fired.

        - Parameter text:   The text to type into the field

        - Throws: `FLTTextFieldError.DisabledTextFieldError` if the 
            text field is disabled.
    */
    public func enterText(text: String) throws {
        try self.enter()
        self.typeText(text)
        self.leave()
    }

    /**
        Types the given text into the text field, firing the .EditingChanged
        event once for each character, as would happen had a real user 
        typed the text into the field.

        If the text field has no delegate, the text is still entered into the
        field and the .EditingChanged event is still fired.

        - Parameter text:   The text to type into the field
    */
    public func typeText(text: String) {
        if isFocused == nil || !isFocused! {
            Logger.logWarning("Attempting to type \"\(text)\" into a UITextField that was never entered")
            return
        }

        if let delegate = delegate {
            for (index, char) in text.characters.enumerate() {
                _ = delegate.textField?(self, shouldChangeCharactersInRange: NSRange.init(location: index, length: 1), replacementString: String(char))
                self.sendActionsForControlEvents(.EditingChanged)
            }
        } else {
            self.text = ""
            for (_, char) in text.characters.enumerate() {
                self.text?.append(char)
                self.sendActionsForControlEvents(.EditingChanged)
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
    public func pasteText(text: String) {
        if isFocused == nil || !isFocused! {
            Logger.logWarning("Attempting to paste \"\(text)\" into a UITextField that was never entered")
            return
        }

        if let delegate = delegate {
            let length = text.characters.count
            _ = delegate.textField?(self, shouldChangeCharactersInRange: NSRange.init(location: 0, length:length), replacementString: text)
        } else {
            self.text = text
        }

        self.sendActionsForControlEvents(.EditingChanged)
    }
}
