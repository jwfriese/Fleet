import UIKit

extension Fleet {
    public enum TextFieldError: Error, CustomStringConvertible {
        case controlUnavailable(String)
        case editingFlow(String)
        case cannotClear(reason: String)

        public var description: String {
            switch self {
            case .controlUnavailable(let message):
                return "UITextField unavailable for editing: \(message)"
            case .editingFlow(let message):
                return "Could not edit UITextField: \(message)"
            case .cannotClear(let reason):
                return "Could not clear text from UITextField: \(reason)"
            }
        }
    }
}

extension UITextField {
    /**
     Attempts to perform the following actions on the `UITextField` in sequence:
     1) Start editing the text field
     2) Type the given text
     3) Stop editing the text field

     It aims to be a functionally equivalent, much shorter version of the following code:
     ```
     var error = textField.startEditing()
     guard error == nil else { // stop }
     error = textField(text: "input text")
     guard error == nil else { // stop }
     error = textField.stopEditing()
     ```

     - parameters:
        - text: The text to enter

     - throws:
     A `Fleet.TextFieldError` if the text field is not available because it is hidden,
     not enabled, if grabbing first responder fails for any reason, or if resigning first responder
     fails for any reason.
     */
    public func enter(text: String) throws {
        try startEditing()
        try type(text: text)
        try stopEditing()
    }

    /**
     Attempts to give the `UITextField` first responder focus.

     - throws:
     A `Fleet.TextFieldError` if the text view is not available because it is hidden,
     not enabled, or if grabbing first responder fails for any reason.
     */
    public func startEditing() throws {
        if !isUserInteractionEnabled {
            throw Fleet.TextFieldError.controlUnavailable("View does not allow user interaction.")
        }
        if isFirstResponder {
            return
        }
        guard !isHidden else {
            throw Fleet.TextFieldError.controlUnavailable("Text field is not visible.")
        }
        guard isEnabled else {
            throw Fleet.TextFieldError.controlUnavailable("Text field is not enabled.")
        }
        sendActions(for: .touchDown)
        if let delegate = delegate {
            let doesImplementShouldBeginEditing = delegate.responds(to: #selector(UITextFieldDelegate.textFieldShouldBeginEditing(_:)))
            if doesImplementShouldBeginEditing {
                guard delegate.textFieldShouldBeginEditing!(self) else {
                    return
                }
            }
        }
        guard becomeFirstResponder() else {
            throw Fleet.TextFieldError.editingFlow("Text field failed to become first responder. This can happen if the field is not part of the window's hierarchy.")
        }
    }

    /**
     Attempts to remove first responder focus from the `UITextField`.

     - throws:
     A `Fleet.TextFieldError` if the text field does not have first responder focus, or if resigning
     first responder fails for any reason.
     */
    public func stopEditing() throws {
        guard isFirstResponder else {
            throw Fleet.TextFieldError.editingFlow("Must start editing the text field before you can stop editing it.")
        }
        if let delegate = delegate {
            let doesImplementShouldEndEditing = delegate.responds(to: #selector(UITextFieldDelegate.textFieldShouldEndEditing(_:)))
            if doesImplementShouldEndEditing {
                guard delegate.textFieldShouldEndEditing!(self) else {
                    return
                }
            }
        }
        guard resignFirstResponder() else {
            throw Fleet.TextFieldError.editingFlow("Text field failed to resign first responder. This can happen if the field is not part of the window's hierarchy.")
        }
    }

    /**
     Attempts to type text into a `UITextField` with first responder focus.

     - parameters:
        - newText: The text to type into the text field

     - throws:
     A `Fleet.TextFieldError` if the text field does not have first responder focus.

     - note:
     This method types the text at the end of any existing text.
     */
    public func type(text newText: String) throws {
        guard isFirstResponder else {
            throw Fleet.TextFieldError.editingFlow("Must start editing the text field before text can be typed into it.")
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
                    insertText(String(character))
                }
            } else {
                insertText(String(character))
            }
        }
    }

    /**
     Attempts to paste text into a `UITextField` with first responder focus.

     - parameters:
        - textToPaste: The text to paste into the text field

     - throws:
     A `Fleet.TextFieldError` if the text field does not have first responder focus.

     - note:
     This method pastes the text to the end of any existing text.
     */
    public func paste(text textToPaste: String) throws {
        guard isFirstResponder else {
            throw Fleet.TextFieldError.editingFlow("Must start editing the text field before text can be pasted into it.")
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
                insertText(textToPaste)
            }
        } else {
            insertText(textToPaste)
        }
    }

    /**
     Attempts to hit the backspace key in a `UITextField` with first responder focus.

     - throws:
     A `Fleet.TextFieldError` if the text field does not have first responder focus.

     - note:
     This method acts at the end of any existing text. That is, it will remove the last character of
     the `UITextField`'s existing text content.
     */
    public func backspace() throws {
        guard isFirstResponder else {
            throw Fleet.TextFieldError.editingFlow("Must start editing the text field before backspaces can be performed.")
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

            return
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
                deleteBackward()
            }
        } else {
            deleteBackward()
        }
    }

    /**
     Clears all text from the text field, firing the `textFieldShouldClear(_:)`
     delegate method as happens when the user clears the field through the UI.

     If the text field has no delegate, the text is still cleared from the
     field.

     - throws:
     A `Fleet.TextFieldError` if an attempt is made to clear a text field while it is in a
     state that does not allow clearing, if the text field is not enabled, or if it is not
     visible.
     */
    public func clearText() throws {
        guard !isHidden else {
            throw Fleet.TextFieldError.controlUnavailable("Text field is not visible.")
        }
        guard isEnabled else {
            throw Fleet.TextFieldError.controlUnavailable("Text field is not enabled.")
        }
        switch clearButtonMode {
        case .never:
            throw Fleet.TextFieldError.cannotClear(reason: "Clear button is never displayed.")
        case.whileEditing:
            guard isFirstResponder else {
                throw Fleet.TextFieldError.cannotClear(reason: "Clear button is hidden when not editing.")
            }
        case.unlessEditing:
            if isFirstResponder {
                throw Fleet.TextFieldError.cannotClear(reason: "Clear button is hidden when editing.")
            }
        case .always:
            break
        }

        var shouldClear = true
        if let delegate = delegate {
            let doesImplementShouldClearText = delegate.responds(to: #selector(UITextFieldDelegate.textFieldShouldClear(_:)))
            if doesImplementShouldClearText {
                shouldClear = delegate.textFieldShouldClear!(self)
            }
        }

        if shouldClear {
            self.text = ""
            sendActions(for: .editingChanged)
        }
    }
}
