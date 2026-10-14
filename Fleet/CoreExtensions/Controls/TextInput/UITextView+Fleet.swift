#if os(iOS)
import UIKit

extension Fleet {
    enum TextViewError: FleetErrorDefinition {
        case controlUnavailable(String)
        case editingFlow(String)
        case legacy(FleetFailure)

        var errorMessage: String {
            switch self {
            case .legacy(let failure):
                return failure.reason
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
        do {
            return try enterOrThrow(text: text) == .performed
        } catch let failure as FleetFailure {
            Fleet.TextEditing.raise(failure, as: Fleet.TextViewError.legacy)
            return false
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
            return false
        }
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
        do {
            return try startEditingOrThrow() == .performed
        } catch let failure as FleetFailure {
            Fleet.TextEditing.raise(failure, as: Fleet.TextViewError.legacy)
            return false
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
            return false
        }
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
        do {
            return try stopEditingOrThrow() == .performed
        } catch let failure as FleetFailure {
            Fleet.TextEditing.raise(failure, as: Fleet.TextViewError.legacy)
            return false
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
            return false
        }
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
        do {
            _ = try typeOrThrow(text: newText)
        } catch let failure as FleetFailure {
            Fleet.TextEditing.raise(failure, as: Fleet.TextViewError.legacy)
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
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
        do {
            _ = try pasteOrThrow(text: textToPaste)
        } catch let failure as FleetFailure {
            Fleet.TextEditing.raise(failure, as: Fleet.TextViewError.legacy)
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
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
        do {
            _ = try backspaceOrThrow()
        } catch let failure as FleetFailure {
            Fleet.TextEditing.raise(failure, as: Fleet.TextViewError.legacy)
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
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
        do {
            _ = try backspaceAllOrThrow()
        } catch let failure as FleetFailure {
            Fleet.TextEditing.raise(failure, as: Fleet.TextViewError.legacy)
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
    }

    fileprivate func shouldChange(_ range: NSRange, replacement: String) -> Bool {
        guard let delegate = delegate,
              delegate.responds(to: #selector(UITextViewDelegate.textView(_:shouldChangeTextIn:replacementText:))) else {
            return true
        }
        return delegate.textView!(self, shouldChangeTextIn: range, replacementText: replacement)
    }

    @discardableResult
    fileprivate func replaceSelection(with replacement: String) -> Bool {
        let range = Fleet.TextEditing.selectedRange(in: self)
        guard shouldChange(range, replacement: replacement) else { return false }
        insertText(replacement)
        return true
    }
}

extension UITextView {
    /// Like `enter(text:)`, but reports failures as a `FleetFailure` instead of raising an `NSException`.
    /// Stops before typing when beginning is refused; returns the refusal outcome of whichever step a delegate vetoed.
    @discardableResult
    public func enterOrThrow(text: String) throws -> FleetInteractionOutcome {
        let began = try startEditingOrThrow()
        guard began == .performed else { return began }
        let typed = try typeOrThrow(text: text)
        let ended = try stopEditingOrThrow()
        guard ended == .performed else { return ended }
        return typed
    }

    /// Like `startEditing()`, but throws a `FleetFailure` (`.unavailableInteraction` when the control cannot be edited,
    /// `.invalidSetup` when it is not in a window) and returns `.refusedByDelegate` when `textViewShouldBeginEditing(_:)` returns `false`.
    @discardableResult
    public func startEditingOrThrow() throws -> FleetInteractionOutcome {
        if !isUserInteractionEnabled {
            throw FleetFailure(kind: .unavailableInteraction, action: "start editing", target: "UITextView",
                               state: "user interaction is disabled",
                               reason: "UITextView unavailable for editing: View does not allow user interaction.")
        }
        if isFirstResponder {
            return .performed
        }
        if isHidden {
            throw FleetFailure(kind: .unavailableInteraction, action: "start editing", target: "UITextView",
                               state: "hidden",
                               reason: "UITextView unavailable for editing: Text view is not visible.")
        }
        if !isSelectable {
            throw FleetFailure(kind: .unavailableInteraction, action: "start editing", target: "UITextView",
                               state: "not selectable",
                               reason: "UITextView unavailable for editing: Text view is not selectable.")
        }
        if !isEditable {
            throw FleetFailure(kind: .unavailableInteraction, action: "start editing", target: "UITextView",
                               state: "not editable",
                               reason: "UITextView unavailable for editing: Text view is not editable.")
        }
        guard becomeFirstResponder() else {
            if window == nil {
                throw FleetFailure(kind: .invalidSetup, action: "start editing", target: "UITextView",
                               state: "the text view is not in a window",
                               reason: "Could not edit UITextView: Text view failed to become first responder. This can happen if the view is not part of the window's hierarchy.")
            }
            // UIKit's canBecomeFirstResponder consults the delegate, so only a delegate implementing the
            // selector can have vetoed; any other failure is an unavailable interaction.
            if !(delegate?.responds(to: #selector(UITextViewDelegate.textViewShouldBeginEditing(_:))) ?? false) {
                throw FleetFailure(kind: .unavailableInteraction, action: "start editing", target: "UITextView",
                                   state: "cannot become first responder (no delegate veto)",
                                   reason: "UITextView unavailable for editing: the control failed to become first responder and no delegate refused.")
            }
            return .refusedByDelegate(method: "textViewShouldBeginEditing(_:)")
        }
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.post(name: UIResponder.keyboardDidShowNotification, object: nil)
        return .performed
    }

    /// Like `stopEditing()`, but throws `.invalidSetup` when not first responder and returns
    /// `.refusedByDelegate` when `textViewShouldEndEditing(_:)` returns `false`.
    @discardableResult
    public func stopEditingOrThrow() throws -> FleetInteractionOutcome {
        guard isFirstResponder else {
            throw FleetFailure(kind: .invalidSetup, action: "stop editing", target: "UITextView",
                               state: "the text view is not first responder",
                               reason: "Could not edit UITextView: Must start editing the text view before you can stop editing it.")
        }
        guard resignFirstResponder() else {
            return .refusedByDelegate(method: "textViewShouldEndEditing(_:)")
        }
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
        return .performed
    }

    /// Like `type(text:)`; returns `.refusedByDelegate` if the delegate vetoed any character.
    @discardableResult
    public func typeOrThrow(text newText: String) throws -> FleetInteractionOutcome {
        guard isFirstResponder else {
            throw FleetFailure(kind: .invalidSetup, action: "type text", target: "UITextView",
                               state: "the text view is not first responder",
                               reason: "Could not edit UITextView: Must start editing the text view before text can be typed into it.")
        }
        var outcome = FleetInteractionOutcome.performed
        for character in newText where !replaceSelection(with: String(character)) {
            outcome = .refusedByDelegate(method: "textView(_:shouldChangeTextIn:replacementText:)")
        }
        return outcome
    }

    /// Like `paste(text:)`; returns `.refusedByDelegate` if the delegate vetoed the change.
    @discardableResult
    public func pasteOrThrow(text textToPaste: String) throws -> FleetInteractionOutcome {
        guard isFirstResponder else {
            throw FleetFailure(kind: .invalidSetup, action: "paste text", target: "UITextView",
                               state: "the text view is not first responder",
                               reason: "Could not edit UITextView: Must start editing the text view before text can be pasted into it.")
        }
        return replaceSelection(with: textToPaste) ? .performed : .refusedByDelegate(method: "textView(_:shouldChangeTextIn:replacementText:)")
    }

    /// Like `backspace()`; returns `.refusedByDelegate` if the delegate vetoed the deletion.
    @discardableResult
    public func backspaceOrThrow() throws -> FleetInteractionOutcome {
        guard isFirstResponder else {
            throw FleetFailure(kind: .invalidSetup, action: "backspace", target: "UITextView",
                               state: "the text view is not first responder",
                               reason: "Could not edit UITextView: Must start editing the text view before backspaces can be performed.")
        }
        let range = Fleet.TextEditing.backspaceRange(in: text ?? "", selection: Fleet.TextEditing.selectedRange(in: self))
        guard shouldChange(range, replacement: "") else {
            return .refusedByDelegate(method: "textView(_:shouldChangeTextIn:replacementText:)")
        }
        if range.length > 0 {
            deleteBackward()
        }
        return .performed
    }

    /// Like `backspaceAll()`; returns `.refusedByDelegate` if the delegate vetoed any deletion.
    @discardableResult
    public func backspaceAllOrThrow() throws -> FleetInteractionOutcome {
        guard isFirstResponder else {
            throw FleetFailure(kind: .invalidSetup, action: "backspace all", target: "UITextView",
                               state: "the text view is not first responder",
                               reason: "Could not edit UITextView: Must start editing the text view before backspaces can be performed.")
        }
        Fleet.TextEditing.moveCaretToEnd(of: self)
        var outcome = FleetInteractionOutcome.performed
        for _ in 0..<(text ?? "").count {
            let step = try backspaceOrThrow()
            if step != .performed { outcome = step }
        }
        return outcome
    }
}

#endif
