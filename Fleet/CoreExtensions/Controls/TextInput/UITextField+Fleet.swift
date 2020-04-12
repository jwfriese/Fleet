import UIKit

extension Fleet {
    enum TextFieldError: FleetErrorDefinition {
        case controlUnavailable(String)
        case editingFlow(String)
        case cannotClear(reason: String)

        var errorMessage: String {
            switch self {
            case .controlUnavailable(let message):
                return "UITextField unavailable for editing: \(message)"
            case .editingFlow(let message):
                return "Could not edit UITextField: \(message)"
            case .cannotClear(let reason):
                return "Could not clear text from UITextField: \(reason)"
            }
        }

        var name: NSExceptionName { get { return NSExceptionName(rawValue: "Fleet.TextFieldError") } }
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
     A `FleetError` if the text field is not available because it is hidden,
     not enabled, if grabbing first responder fails for any reason, or if resigning first responder
     fails for any reason.
     */
    public func enter(text: String) {
        startEditing()
        type(text: text)
        stopEditing()
    }

    /**
     Attempts to give the `UITextField` first responder focus.

     - throws:
     A `FleetError` if the text view is not available because it is hidden,
     not enabled, or if grabbing first responder fails for any reason.
     */
    public func startEditing() {
        if !isUserInteractionEnabled {
            FleetError(Fleet.TextFieldError.controlUnavailable("View does not allow user interaction.")).raise()
            return
        }
        if isFirstResponder {
            return
        }
        guard !isHidden else {
            FleetError(Fleet.TextFieldError.controlUnavailable("Text field is not visible.")).raise()
            return
        }
        guard isEnabled else {
            FleetError(Fleet.TextFieldError.controlUnavailable("Text field is not enabled.")).raise()
            return
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
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil)
        guard becomeFirstResponder() else {
            FleetError(Fleet.TextFieldError.editingFlow("Text field failed to become first responder. This can happen if the field is not part of the window's hierarchy.")).raise()
            return
        }
        NotificationCenter.default.post(name: UIResponder.keyboardDidShowNotification, object: nil)
    }

    /**
     Attempts to remove first responder focus from the `UITextField`.

     - throws:
     A `FleetError` if the text field does not have first responder focus, or if resigning
     first responder fails for any reason.
     */
    public func stopEditing() {
        guard isFirstResponder else {
            FleetError(Fleet.TextFieldError.editingFlow("Must start editing the text field before you can stop editing it.")).raise()
            return
        }
        if let delegate = delegate {
            let doesImplementShouldEndEditing = delegate.responds(to: #selector(UITextFieldDelegate.textFieldShouldEndEditing(_:)))
            if doesImplementShouldEndEditing {
                guard delegate.textFieldShouldEndEditing!(self) else {
                    return
                }
            }
        }
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil)
        guard resignFirstResponder() else {
            FleetError(Fleet.TextFieldError.editingFlow("Text field failed to resign first responder. This can happen if the field is not part of the window's hierarchy.")).raise()
            return
        }
        NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
    }

    /**
     Attempts to type text into a `UITextField` with first responder focus.

     - parameters:
        - newText: The text to type into the text field

     - throws:
     A `FleetError` if the text field does not have first responder focus.

     - note:
     This method types the text at the end of any existing text.
     */
    public func type(text newText: String) {
        guard isFirstResponder else {
            FleetError(Fleet.TextFieldError.editingFlow("Must start editing the text field before text can be typed into it.")).raise()
            return
        }

        for character in newText {
            var existingText = ""
            if let unwrappedText = text {
                existingText = unwrappedText
            }
            if let delegate = delegate {
                let doesImplementShouldChangeText = delegate.responds(to: #selector(UITextFieldDelegate.textField(_:shouldChangeCharactersIn:replacementString:)))
                var doesAllowTextChange = true
                if doesImplementShouldChangeText {
                    doesAllowTextChange = delegate.textField!(self, shouldChangeCharactersIn: NSMakeRange(existingText.count, 0), replacementString: String(character))
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
     A `FleetError` if the text field does not have first responder focus.

     - note:
     This method pastes the text to the end of any existing text.
     */
    public func paste(text textToPaste: String) {
        guard isFirstResponder else {
            FleetError(Fleet.TextFieldError.editingFlow("Must start editing the text field before text can be pasted into it.")).raise()
            return
        }

        var existingText = ""
        if let unwrappedText = text {
            existingText = unwrappedText
        }
        if let delegate = delegate {
            let doesImplementShouldChangeText = delegate.responds(to: #selector(UITextFieldDelegate.textField(_:shouldChangeCharactersIn:replacementString:)))
            var doesAllowTextChange = true
            if doesImplementShouldChangeText {
                doesAllowTextChange = delegate.textField!(self, shouldChangeCharactersIn: NSMakeRange(existingText.count, 0), replacementString: textToPaste)
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
     A `FleetError` if the text field does not have first responder focus.

     - note:
     This method acts at the end of any existing text. That is, it will remove the last character of
     the `UITextField`'s existing text content.
     */
    public func backspace() {
        guard isFirstResponder else {
            FleetError(Fleet.TextFieldError.editingFlow("Must start editing the text field before backspaces can be performed.")).raise()
            return
        }

        var existingText = ""
        if let unwrappedText = text {
            existingText = unwrappedText
        }
        if existingText == "" {
            if let delegate = delegate {
                let doesImplementShouldChangeText = delegate.responds(to: #selector(UITextFieldDelegate.textField(_:shouldChangeCharactersIn:replacementString:)))
                if doesImplementShouldChangeText {
                    let _ = delegate.textField!(self, shouldChangeCharactersIn: NSMakeRange(0, 0), replacementString: "")
                }
            }

            return
        }
        if let delegate = delegate {
            let location = existingText.count > 0 ? existingText.count - 1 : 0
            let backspaceAmount = existingText.count > 0 ? 1 : 0
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
     Deletes all text from the text field, as though the user hit the backspace button once for each
     character in the text field.

     - throws:
     A `FleetError` if the text field does not have first responder focus.
     */
    public func backspaceAll() {
        guard isFirstResponder else {
            FleetError(Fleet.TextFieldError.editingFlow("Must start editing the text field before backspaces can be performed.")).raise()
            return
        }

        var characterCount = 0
        if let unwrappedText = text {
            characterCount = unwrappedText.count
        }

        for _ in 0..<characterCount {
            backspace()
        }
    }

    /**
     Clears all text from the text field, firing the `textFieldShouldClear(_:)`
     delegate method as happens when the user clears the field through the UI.

     If the text field has no delegate, the text is still cleared from the
     field.

     - throws:
     A `FleetError` if an attempt is made to clear a text field while it is in a
     state that does not allow clearing, if the text field is not enabled, or if it is not
     visible.
     */
    public func clearText() {
        guard !isHidden else {
            FleetError(Fleet.TextFieldError.controlUnavailable("Text field is not visible.")).raise()
            return
        }
        guard isEnabled else {
            FleetError(Fleet.TextFieldError.controlUnavailable("Text field is not enabled.")).raise()
            return
        }
        switch clearButtonMode {
        case .never:
            FleetError(Fleet.TextFieldError.cannotClear(reason: "Clear button is never displayed.")).raise()
            return
        case.whileEditing:
            guard isFirstResponder else {
                FleetError(Fleet.TextFieldError.cannotClear(reason: "Clear button is hidden when not editing.")).raise()
                return
            }
        case.unlessEditing:
            if isFirstResponder {
                FleetError(Fleet.TextFieldError.cannotClear(reason: "Clear button is hidden when editing.")).raise()
                return
            }
        case .always:
            break
        default:
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
