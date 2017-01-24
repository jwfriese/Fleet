import UIKit

extension UITextView {
    /**
     Attempts to perform the following actions on the `UITextView` in sequence:
     1) Start editing the text view
     2) Type the given text
     3) Stop editing the text view

     It aims to be a functionally equivalent, much shorter version of the following code:
     ```
     var error = textView.startEditing()
     guard error == nil else { // stop }
     error = textView.type(text: "input text")
     guard error == nil else { // stop }
     error = textView.stopEditing()
     ```

     - returns:
     `nil` if successful, or a `FleetError` if the text view is not available because it is hidden,
     not selectable, not editable, if grabbing first responder fails for any reason, or if resigning
     first responder fails for any reason.
     */
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

    /**
     Attempts to give the `UITextView` first responder focus.

     - returns:
     `nil` if successful, or a `FleetError` if the text view is not available because it is hidden,
     not selectable, not editable, or if grabbing first responder fails for any reason.
     */
    public func startEditing() -> FleetError? {
        if !isUserInteractionEnabled {
            return FleetError(message: "Failed to start editing UITextView: User interaction is disabled.")
        }
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
            let doesImplementShouldBeginEditing = delegate.responds(to: #selector(UITextViewDelegate.textViewShouldBeginEditing(_:)))
            if doesImplementShouldBeginEditing {
                guard delegate.textViewShouldBeginEditing!(self) else {
                    return nil
                }
            }
        }
        guard becomeFirstResponder() else {
            return FleetError(message: "UITextView failed to become first responder. Make sure that the view is a part of the key window's view hierarchy.")
        }

        return nil
    }

    /**
     Attempts to remove first responder focus from the `UITextView`.

     - returns:
     `nil` if successful, or a `FleetError` if the text view does not have first responder focus, or if resigning
     first responder fails for any reason.
     */
    public func stopEditing() -> FleetError? {
        guard isFirstResponder else {
            return FleetError(message: "Could not stop editing UITextView: Must start editing the text view before you can stop editing it.")
        }
        if let delegate = delegate {
            let doesImplementShouldEndEditing = delegate.responds(to: #selector(UITextViewDelegate.textViewShouldEndEditing(_:)))
            if doesImplementShouldEndEditing {
                guard delegate.textViewShouldEndEditing!(self) else {
                    return nil
                }
            }
        }
        guard resignFirstResponder() else {
            return FleetError(message: "UITextView failed to resign first responder. Make sure that the view is a part of the key window's view hierarchy.")
        }

        return nil
    }

    /**
     Attempts to type text into a `UITextView` with first responder focus.

     - returns:
     `nil` if successful, or a `FleetError` if the text view does not have first responder focus.

     - note:
     This method types the text at the end of any existing text.
     */
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
                let doesImplementShouldChangeText = delegate.responds(to: #selector(UITextViewDelegate.textView(_:shouldChangeTextIn:replacementText:)))
                var doesAllowTextChange = true
                if doesImplementShouldChangeText {
                    doesAllowTextChange = delegate.textView!(self, shouldChangeTextIn: NSMakeRange(existingText.characters.count, 0), replacementText: String(character))
                }
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

    /**
     Attempts to paste text into a `UITextView` with first responder focus.

     - returns:
     `nil` if successful, or a `FleetError` if the text view does not have first responder focus.

     - note:
     This method pastes the text to the end of any existing text.
     */
    public func paste(text textToPaste: String) -> FleetError? {
        guard isFirstResponder else {
            return FleetError(message: "Could not paste text into UITextView: Must start editing the text view before text can be pasted into it.")
        }

        var existingText = ""
        if let unwrappedText = text {
            existingText = unwrappedText
        }
        if let delegate = delegate {
            let doesImplementShouldChangeText = delegate.responds(to: #selector(UITextViewDelegate.textView(_:shouldChangeTextIn:replacementText:)))
            var doesAllowTextChange = true
            if doesImplementShouldChangeText {
                doesAllowTextChange = delegate.textView!(self, shouldChangeTextIn: NSMakeRange(existingText.characters.count, 0), replacementText: textToPaste)
            }
            if doesAllowTextChange {
                delegate.textViewDidChange?(self)
                text.append(textToPaste)
            }
        } else {
            text.append(textToPaste)
        }

        return nil
    }

    /**
     Attempts to hit the backspace key in a `UITextView` with first responder focus.

     - returns:
     `nil` if successful, or a `FleetError` if the text view does not have first responder focus.

     - note:
     This method acts at the end of any existing text. That is, it will remove the last character of
     the `UITextView`'s existing text content.
     */
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
            let doesImplementShouldChangeText = delegate.responds(to: #selector(UITextViewDelegate.textView(_:shouldChangeTextIn:replacementText:)))
            var doesAllowTextChange = true
            if doesImplementShouldChangeText {
                doesAllowTextChange = delegate.textView!(self, shouldChangeTextIn: NSMakeRange(location, backspaceAmount), replacementText: "")
            }
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
