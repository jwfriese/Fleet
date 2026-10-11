#if os(iOS)
import UIKit

extension Fleet {
    enum TextViewError: FleetErrorDefinition {
        case controlUnavailable(String)
        case editingFlow(String)

        var errorMessage: String {
            switch self {
            case .controlUnavailable(let message):
                return "UITextView unavailable for editing: \(message)"
            case .editingFlow(let message):
                return "Could not edit UITextView: \(message)"
            }
        }

        var name: NSExceptionName { get { return NSExceptionName(rawValue: "Fleet.TextViewError") } }
    }
}

extension UITextView {
    /**
     Attempts to perform the following actions on the `UITextView` in sequence:
     1) Start editing the text view
     2) Type the given text
     3) Stop editing the text view

     If the delegate refuses to let editing begin, the sequence stops before any text is typed.

     - parameters:
        - text: The text to enter

     - returns:
     `true` if editing began, the text was typed, and editing ended. `false` if the delegate refused
     to begin editing (nothing is typed) or refused to end editing (the text was typed and the
     view remains first responder).

     - throws:
     A `FleetError` if the text view is not available because it is hidden, not selectable or
     not editable, or if grabbing first responder fails because the view is not in a window.
     */
    @discardableResult
    public func enter(text: String) -> Bool {
        guard startEditing() else { return false }
        type(text: text)
        return stopEditing()
    }

    /**
     Attempts to give the `UITextView` first responder focus.

     The delegate's `textViewShouldBeginEditing(_:)` is consulted once, by UIKit, as part of
     becoming first responder. A delegate refusal is not an error: the view keeps its previous
     focus state, the method returns `false`, and no `textViewDidBeginEditing(_:)` is sent.

     On success, `keyboardWillShowNotification` and `keyboardDidShowNotification` are posted with no
     `object` or `userInfo`, after focus has changed. These are simulated notifications for observers;
     Fleet does not present or measure an actual keyboard.

     - returns:
     `true` if the text view is first responder afterwards, `false` if focus was refused.

     - throws:
     A `FleetError` if the text view is not available because it is hidden, not selectable or
     not editable, or if it cannot become first responder because it is not part of a window's hierarchy.
     */
    @discardableResult
    public func startEditing() -> Bool {
        if !isUserInteractionEnabled {
            FleetError(Fleet.TextViewError.controlUnavailable("View does not allow user interaction.")).raise()
            return false
        }
        if isFirstResponder {
            return true
        }
        guard !isHidden else {
            FleetError(Fleet.TextViewError.controlUnavailable("Text view is not visible.")).raise()
            return false
        }
        guard isSelectable else {
            FleetError(Fleet.TextViewError.controlUnavailable("Text view is not selectable.")).raise()
            return false
        }
        guard isEditable else {
            FleetError(Fleet.TextViewError.controlUnavailable("Text view is not editable.")).raise()
            return false
        }
        guard becomeFirstResponder() else {
            if window == nil {
                FleetError(Fleet.TextViewError.editingFlow("Text view failed to become first responder. This can happen if the view is not part of the window's hierarchy.")).raise()
            }
            return false
        }
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.post(name: UIResponder.keyboardDidShowNotification, object: nil)
        return true
    }

    /**
     Attempts to remove first responder focus from the `UITextView`.

     The delegate's `textViewShouldEndEditing(_:)` is consulted once, by UIKit, as part of resigning
     first responder. A delegate refusal is not an error: the view remains first responder, the method
     returns `false`, and no `textViewDidEndEditing(_:)` is sent.

     On success, `keyboardWillHideNotification` and `keyboardDidHideNotification` are posted with no
     `object` or `userInfo`, after focus has changed. These are simulated notifications; Fleet does not
     dismiss an actual keyboard.

     - returns:
     `true` if the text view is no longer first responder, `false` if resigning was refused.

     - throws:
     A `FleetError` if the text view does not have first responder focus.
     */
    @discardableResult
    public func stopEditing() -> Bool {
        guard isFirstResponder else {
            FleetError(Fleet.TextViewError.editingFlow("Must start editing the text view before you can stop editing it.")).raise()
            return false
        }
        guard resignFirstResponder() else {
            return false
        }
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
        return true
    }

    /**
     Attempts to type text into a `UITextView` with first responder focus.

     - parameters:
        - newText: The text to type into the text view

     - throws:
     A `FleetError` if the text view does not have first responder focus.

     - note:
     Text is typed one character (grapheme cluster, so an emoji or a base letter with its combining
     marks is a single character) at a time at the current selection. A non-empty selection is replaced
     by the first character. For each character the delegate's
     `textView(_:shouldChangeTextIn:replacementText:)` receives the selection as a UTF-16 range;
     if it returns `false` that character is skipped and typing continues with the next.
     */
    public func type(text newText: String) {
        guard isFirstResponder else {
            FleetError(Fleet.TextViewError.editingFlow("Must start editing the text view before text can be typed into it.")).raise()
            return
        }

        for character in newText {
            replaceSelection(with: String(character))
        }
    }

    /**
     Attempts to paste text into a `UITextView` with first responder focus.

     - parameters:
        - textToPaste: The text to paste into the text view

     - throws:
     A `FleetError` if the text view does not have first responder focus.

     - note:
     The text replaces the current selection, or is inserted at the caret, as a single change reported
     to the delegate with a UTF-16 range. If the delegate refuses, the text is unchanged.
     */
    public func paste(text textToPaste: String) {
        guard isFirstResponder else {
            FleetError(Fleet.TextViewError.editingFlow("Must start editing the text view before text can be pasted into it.")).raise()
            return
        }

        replaceSelection(with: textToPaste)
    }

    /**
     Attempts to hit the backspace key in a `UITextView` with first responder focus.

     - throws:
     A `FleetError` if the text view does not have first responder focus.

     - note:
     A non-empty selection is deleted. Otherwise this removes the whole composed character sequence
     before the caret (an emoji or a letter with combining marks goes in one backspace). The delegate
     receives the UTF-16 range being removed, and if it returns `false` nothing is removed. With the
     caret at the start of the text the delegate is asked about an empty range at location 0 and
     nothing changes.
     */
    public func backspace() {
        guard isFirstResponder else {
            FleetError(Fleet.TextViewError.editingFlow("Must start editing the text view before backspaces can be performed.")).raise()
            return
        }

        let range = Fleet.TextEditing.backspaceRange(in: text ?? "", selection: Fleet.TextEditing.selectedRange(in: self))
        if shouldChange(range, replacement: "") && range.length > 0 {
            deleteBackward()
        }
    }

    /**
     Deletes all text from the text view, as though the user hit the backspace button once for each
     character in the text view.

     - throws:
     A `FleetError` if the text view does not have first responder focus.

     - note:
     The caret is first moved to the end of the text, collapsing any selection, so the whole content is
     addressed regardless of where the user left the caret. A delegate that refuses a change leaves the
     text in place; each backspace is still offered to it.
     */
    public func backspaceAll() {
        guard isFirstResponder else {
            FleetError(Fleet.TextViewError.editingFlow("Must start editing the text view before backspaces can be performed.")).raise()
            return
        }

        Fleet.TextEditing.moveCaretToEnd(of: self)
        let characterCount = (text ?? "").count

        for _ in 0..<characterCount {
            backspace()
        }
    }

    private func shouldChange(_ range: NSRange, replacement: String) -> Bool {
        guard let delegate = delegate,
              delegate.responds(to: #selector(UITextViewDelegate.textView(_:shouldChangeTextIn:replacementText:))) else {
            return true
        }
        return delegate.textView!(self, shouldChangeTextIn: range, replacementText: replacement)
    }

    private func replaceSelection(with replacement: String) {
        let range = Fleet.TextEditing.selectedRange(in: self)
        if shouldChange(range, replacement: replacement) {
            insertText(replacement)
        }
    }
}

#endif
