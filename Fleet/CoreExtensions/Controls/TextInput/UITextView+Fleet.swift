import UIKit

extension Fleet {
    public enum TextViewError: Error, CustomStringConvertible {
        case controlUnavailable(String)
        case editingFlow(String)

        public var description: String {
            switch self {
            case .controlUnavailable(let message):
                return "UITextView unavailable for editing: \(message)"
            case .editingFlow(let message):
                return "Could not edit UITextView: \(message)"
            }
        }
    }
}

extension UITextView {
    /**
     Attempts to perform the following actions on the `UITextView` in sequence:
     1) Start editing the text view
     2) Type the given text
     3) Stop editing the text view

     It aims to be a functionally equivalent, much shorter version of the following code:
     ```
     try! textView.startEditing()
     try! textView.type(text: "input text")
     try! textView.stopEditing()
     ```

     - parameters:
        - text: The text to enter into the text view

     - throws:
     A `Fleet.TextViewError` if the text view is not available because it is hidden,
     not selectable, not editable, if grabbing first responder fails for any reason, or if resigning
     first responder fails for any reason.
     */
    public func enter(text: String) throws {
        try startEditing()
        try type(text: text)
        try stopEditing()
    }

    /**
     Attempts to give the `UITextView` first responder focus.

     - throws:
     A `Fleet.TextViewError` if the text view is not available because it is hidden,
     not selectable, not editable, or if grabbing first responder fails for any reason.
     */
    public func startEditing() throws {
        if !isUserInteractionEnabled {
            throw Fleet.TextViewError.controlUnavailable("View does not allow user interaction.")
        }
        if isFirstResponder {
            return
        }
        guard !isHidden else {
            throw Fleet.TextViewError.controlUnavailable("Text view is not visible.")
        }
        guard isSelectable else {
            throw Fleet.TextViewError.controlUnavailable("Text view is not selectable.")
        }
        guard isEditable else {
            throw Fleet.TextViewError.controlUnavailable("Text view is not editable.")
        }
        if let delegate = delegate {
            let doesImplementShouldBeginEditing = delegate.responds(to: #selector(UITextViewDelegate.textViewShouldBeginEditing(_:)))
            if doesImplementShouldBeginEditing {
                guard delegate.textViewShouldBeginEditing!(self) else {
                    return
                }
            }
        }
        guard becomeFirstResponder() else {
            throw Fleet.TextViewError.editingFlow("Text view failed to become first responder. This can happen if the view is not part of the window's hierarchy.")
        }
    }

    /**
     Attempts to remove first responder focus from the `UITextView`.

     - throws:
     A `Fleet.TextViewError` if the text view does not have first responder focus, or if resigning
     first responder fails for any reason.
     */
    public func stopEditing() throws {
        guard isFirstResponder else {
            throw Fleet.TextViewError.editingFlow("Must start editing the text view before you can stop editing it.")
        }
        if let delegate = delegate {
            let doesImplementShouldEndEditing = delegate.responds(to: #selector(UITextViewDelegate.textViewShouldEndEditing(_:)))
            if doesImplementShouldEndEditing {
                guard delegate.textViewShouldEndEditing!(self) else {
                    return
                }
            }
        }
        guard resignFirstResponder() else {
            throw Fleet.TextViewError.editingFlow("Text view failed to resign first responder. This can happen if the view is not part of the window's hierarchy.")
        }
    }

    /**
     Attempts to type text into a `UITextView` with first responder focus.

     - parameters:
        - newText: The text to type into the text view

     - throws:
     A `Fleet.TextViewError` if the text view does not have first responder focus.

     - note:
     This method types the text at the end of any existing text.
     */
    public func type(text newText: String) throws {
        guard isFirstResponder else {
            throw Fleet.TextViewError.editingFlow("Must start editing the text view before text can be typed into it.")
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
                    insertText(String(character))
                }
            } else {
                insertText(String(character))
            }
        }
    }

    /**
     Attempts to paste text into a `UITextView` with first responder focus.

     - parameters:
        - textToPaste: The text to paste into the text view

     - throws:
     A `Fleet.TextViewError` if the text view does not have first responder focus.

     - note:
     This method pastes the text to the end of any existing text.
     */
    public func paste(text textToPaste: String) throws {
        guard isFirstResponder else {
            throw Fleet.TextViewError.editingFlow("Must start editing the text view before text can be pasted into it.")
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
                insertText(textToPaste)
            }
        } else {
            insertText(textToPaste)
        }
    }

    /**
     Attempts to hit the backspace key in a `UITextView` with first responder focus.

     - throws:
     A `Fleet.TextViewError` if the text view does not have first responder focus.

     - note:
     This method acts at the end of any existing text. That is, it will remove the last character of
     the `UITextView`'s existing text content.
     */
    public func backspace() throws {
        guard isFirstResponder else {
            throw Fleet.TextViewError.editingFlow("Must start editing the text view before backspaces can be performed.")
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

            return
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
                deleteBackward()
            }
        } else {
            deleteBackward()
        }
    }
}
