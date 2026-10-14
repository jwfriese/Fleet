#if os(iOS)
import UIKit

extension Fleet {
    enum TextFieldError: FleetErrorDefinition {
        case controlUnavailable(String)
        case editingFlow(String)
        case legacy(FleetFailure)
        case cannotClear(reason: String)

        var errorMessage: String {
            switch self {
            case .legacy(let failure):
                return failure.reason
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

extension Fleet {
    /// Selection and deletion coordinates shared by the text field and text view helpers.
    /// All ranges are UTF-16 `NSRange` values, the coordinates UIKit delegates receive.
    enum TextEditing {
        /// Raises the legacy `FleetError` for a failure reported by a throwing helper; the failure's
        /// `reason` carries the historical exception message.
        static func raise(_ failure: FleetFailure, as make: (FleetFailure) -> FleetErrorDefinition) {
            FleetError(make(failure)).raise()
        }
        /// The caret or selected range of `input`; the start of the document if nothing is selected.
        static func selectedRange(in input: UITextInput) -> NSRange {
            guard let range = input.selectedTextRange else { return NSRange(location: 0, length: 0) }
            let location = input.offset(from: input.beginningOfDocument, to: range.start)
            let length = input.offset(from: range.start, to: range.end)
            return NSRange(location: location, length: length)
        }

        /// The range a backspace removes: the selection if there is one, otherwise the composed
        /// character sequence before the caret (a zero-length range at the start of the text).
        static func backspaceRange(in text: String, selection: NSRange) -> NSRange {
            if selection.length > 0 { return selection }
            let nsText = text as NSString
            let caret = min(selection.location, nsText.length)
            if caret == 0 { return NSRange(location: 0, length: 0) }
            return nsText.rangeOfComposedCharacterSequence(at: caret - 1)
        }

        /// Moves the caret to the end of the document, collapsing any selection.
        static func moveCaretToEnd(of input: UITextInput) {
            let end = input.endOfDocument
            if let current = input.selectedTextRange, current.isEmpty, current.start == end { return }
            input.selectedTextRange = input.textRange(from: end, to: end)
        }
    }
}

extension UITextField {
    /**
     Attempts to perform the following actions on the `UITextField` in sequence:
     1) Start editing the text field
     2) Type the given text
     3) Stop editing the text field

     If the delegate refuses to let editing begin, the sequence stops before any text is typed.

     - parameters:
        - text: The text to enter

     - returns:
     `true` if editing began, the text was typed, and editing ended. `false` if the delegate refused
     to begin editing (nothing is typed) or refused to end editing (the text was typed and the
     field remains first responder).

     - throws:
     A `FleetError` if the text field is not available because it is hidden,
     not enabled, or if grabbing first responder fails because the field is not in a window.
     */
    @discardableResult
    public func enter(text: String) -> Bool {
        do {
            return try enterOrThrow(text: text) == .performed
        } catch let failure as FleetFailure {
            Fleet.TextEditing.raise(failure, as: Fleet.TextFieldError.legacy)
            return false
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
            return false
        }
    }

    /**
     Attempts to give the `UITextField` first responder focus.

     The delegate's `textFieldShouldBeginEditing(_:)` is consulted once, by UIKit, as part of
     becoming first responder. A delegate refusal is not an error: the field keeps its previous
     focus state, the method returns `false`, and no `textFieldDidBeginEditing(_:)` is sent.
     A `.touchDown` control event is sent either way.

     On success, `keyboardWillShowNotification` and `keyboardDidShowNotification` are posted with no
     `object` or `userInfo`, after focus has changed. These are simulated notifications for observers;
     Fleet does not present or measure an actual keyboard.

     - returns:
     `true` if the text field is first responder afterwards, `false` if focus was refused.

     - throws:
     A `FleetError` if the text field is not available because it is hidden or not enabled,
     or if it cannot become first responder because it is not part of a window's hierarchy.
     */
    @discardableResult
    public func startEditing() -> Bool {
        do {
            return try startEditingOrThrow() == .performed
        } catch let failure as FleetFailure {
            Fleet.TextEditing.raise(failure, as: Fleet.TextFieldError.legacy)
            return false
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
            return false
        }
    }

    /**
     Attempts to remove first responder focus from the `UITextField`.

     The delegate's `textFieldShouldEndEditing(_:)` is consulted once, by UIKit, as part of resigning
     first responder. A delegate refusal is not an error: the field remains first responder, the method
     returns `false`, and no `textFieldDidEndEditing(_:)` is sent.

     On success, `keyboardWillHideNotification` and `keyboardDidHideNotification` are posted with no
     `object` or `userInfo`, after focus has changed. These are simulated notifications; Fleet does not
     dismiss an actual keyboard.

     - returns:
     `true` if the text field is no longer first responder, `false` if resigning was refused.

     - throws:
     A `FleetError` if the text field does not have first responder focus.
     */
    @discardableResult
    public func stopEditing() -> Bool {
        do {
            return try stopEditingOrThrow() == .performed
        } catch let failure as FleetFailure {
            Fleet.TextEditing.raise(failure, as: Fleet.TextFieldError.legacy)
            return false
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
            return false
        }
    }

    /**
     Attempts to type text into a `UITextField` with first responder focus.

     - parameters:
        - newText: The text to type into the text field

     - throws:
     A `FleetError` if the text field does not have first responder focus.

     - note:
     Text is typed one character (grapheme cluster, so an emoji or a base letter with its combining
     marks is a single character) at a time at the current selection. A non-empty selection is replaced
     by the first character. For each character the delegate's
     `textField(_:shouldChangeCharactersIn:replacementString:)` receives the selection as a UTF-16 range;
     if it returns `false` that character is skipped and typing continues with the next.
     */
    public func type(text newText: String) {
        do {
            _ = try typeOrThrow(text: newText)
        } catch let failure as FleetFailure {
            Fleet.TextEditing.raise(failure, as: Fleet.TextFieldError.legacy)
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
    }

    /**
     Attempts to paste text into a `UITextField` with first responder focus.

     - parameters:
        - textToPaste: The text to paste into the text field

     - throws:
     A `FleetError` if the text field does not have first responder focus.

     - note:
     The text replaces the current selection, or is inserted at the caret, as a single change reported
     to the delegate with a UTF-16 range. If the delegate refuses, the text is unchanged.
     */
    public func paste(text textToPaste: String) {
        do {
            _ = try pasteOrThrow(text: textToPaste)
        } catch let failure as FleetFailure {
            Fleet.TextEditing.raise(failure, as: Fleet.TextFieldError.legacy)
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
    }

    /**
     Attempts to hit the backspace key in a `UITextField` with first responder focus.

     - throws:
     A `FleetError` if the text field does not have first responder focus.

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
            Fleet.TextEditing.raise(failure, as: Fleet.TextFieldError.legacy)
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
    }

    /**
     Deletes all text from the text field, as though the user hit the backspace button once for each
     character in the text field.

     - throws:
     A `FleetError` if the text field does not have first responder focus.

     - note:
     The caret is first moved to the end of the text, collapsing any selection, so the whole content is
     addressed regardless of where the user left the caret. A delegate that refuses a change leaves the
     text in place; each backspace is still offered to it.
     */
    public func backspaceAll() {
        do {
            _ = try backspaceAllOrThrow()
        } catch let failure as FleetFailure {
            Fleet.TextEditing.raise(failure, as: Fleet.TextFieldError.legacy)
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
    }

    fileprivate func shouldChange(_ range: NSRange, replacement: String) -> Bool {
        guard let delegate = delegate,
              delegate.responds(to: #selector(UITextFieldDelegate.textField(_:shouldChangeCharactersIn:replacementString:))) else {
            return true
        }
        return delegate.textField!(self, shouldChangeCharactersIn: range, replacementString: replacement)
    }

    @discardableResult
    fileprivate func replaceSelection(with replacement: String) -> Bool {
        let range = Fleet.TextEditing.selectedRange(in: self)
        guard shouldChange(range, replacement: replacement) else { return false }
        insertText(replacement)
        return true
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

extension UITextField {
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
    /// `.invalidSetup` when it is not in a window) and returns `.refusedByDelegate` when `textFieldShouldBeginEditing(_:)` returns `false`.
    @discardableResult
    public func startEditingOrThrow() throws -> FleetInteractionOutcome {
        if !isUserInteractionEnabled {
            throw FleetFailure(kind: .unavailableInteraction, action: "start editing", target: "UITextField",
                               state: "user interaction is disabled",
                               reason: "UITextField unavailable for editing: View does not allow user interaction.")
        }
        if isFirstResponder {
            return .performed
        }
        if isHidden {
            throw FleetFailure(kind: .unavailableInteraction, action: "start editing", target: "UITextField",
                               state: "hidden",
                               reason: "UITextField unavailable for editing: Text field is not visible.")
        }
        if !isEnabled {
            throw FleetFailure(kind: .unavailableInteraction, action: "start editing", target: "UITextField",
                               state: "not enabled",
                               reason: "UITextField unavailable for editing: Text field is not enabled.")
        }
        sendActions(for: .touchDown)
        let vetoRecorder = BeginEditingVetoRecorder(wrapping: delegate)
        let originalDelegate = delegate
        if originalDelegate != nil { delegate = vetoRecorder }
        let didBecome = becomeFirstResponder()
        // Restore only if the recorder is still installed, preserving delegate changes made by callbacks.
        if originalDelegate != nil, delegate === vetoRecorder { delegate = originalDelegate }
        guard didBecome else {
            if window == nil {
                throw FleetFailure(kind: .invalidSetup, action: "start editing", target: "UITextField",
                               state: "the text field is not in a window",
                               reason: "Could not edit UITextField: Text field failed to become first responder. This can happen if the field is not part of the window's hierarchy.")
            }
            // UIKit consults the delegate from canBecomeFirstResponder, so a veto is only reported when the
            // recorder observed the delegate return false; any other failure is an unavailable interaction.
            if !vetoRecorder.vetoed {
                throw FleetFailure(kind: .unavailableInteraction, action: "start editing", target: "UITextField",
                                   state: "cannot become first responder (no delegate veto)",
                                   reason: "UITextField unavailable for editing: the control failed to become first responder and no delegate refused.")
            }
            return .refusedByDelegate(method: "textFieldShouldBeginEditing(_:)")
        }
        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.post(name: UIResponder.keyboardDidShowNotification, object: nil)
        return .performed
    }

    /// Like `stopEditing()`, but throws `.invalidSetup` when not first responder and returns
    /// `.refusedByDelegate` when `textFieldShouldEndEditing(_:)` returns `false`.
    @discardableResult
    public func stopEditingOrThrow() throws -> FleetInteractionOutcome {
        guard isFirstResponder else {
            throw FleetFailure(kind: .invalidSetup, action: "stop editing", target: "UITextField",
                               state: "the text field is not first responder",
                               reason: "Could not edit UITextField: Must start editing the text field before you can stop editing it.")
        }
        let vetoRecorder = BeginEditingVetoRecorder(wrapping: delegate)
        let originalDelegate = delegate
        if originalDelegate != nil { delegate = vetoRecorder }
        let didResign = resignFirstResponder()
        // Restore only if the recorder is still installed, preserving delegate changes made by callbacks.
        if originalDelegate != nil, delegate === vetoRecorder { delegate = originalDelegate }
        guard didResign else {
            // Only report a veto the recorder actually observed; any other resignation failure is unavailable.
            if !vetoRecorder.endVetoed {
                throw FleetFailure(kind: .unavailableInteraction, action: "stop editing", target: "UITextField",
                                   state: "cannot resign first responder (no delegate veto)",
                                   reason: "UITextField unavailable for editing: the control failed to resign first responder and no delegate refused.")
            }
            return .refusedByDelegate(method: "textFieldShouldEndEditing(_:)")
        }
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
        return .performed
    }

    /// Like `type(text:)`; returns `.refusedByDelegate` if the delegate vetoed any character.
    @discardableResult
    public func typeOrThrow(text newText: String) throws -> FleetInteractionOutcome {
        guard isFirstResponder else {
            throw FleetFailure(kind: .invalidSetup, action: "type text", target: "UITextField",
                               state: "the text field is not first responder",
                               reason: "Could not edit UITextField: Must start editing the text field before text can be typed into it.")
        }
        var outcome = FleetInteractionOutcome.performed
        for character in newText where !replaceSelection(with: String(character)) {
            outcome = .refusedByDelegate(method: "textField(_:shouldChangeCharactersIn:replacementString:)")
        }
        return outcome
    }

    /// Like `paste(text:)`; returns `.refusedByDelegate` if the delegate vetoed the change.
    @discardableResult
    public func pasteOrThrow(text textToPaste: String) throws -> FleetInteractionOutcome {
        guard isFirstResponder else {
            throw FleetFailure(kind: .invalidSetup, action: "paste text", target: "UITextField",
                               state: "the text field is not first responder",
                               reason: "Could not edit UITextField: Must start editing the text field before text can be pasted into it.")
        }
        return replaceSelection(with: textToPaste) ? .performed : .refusedByDelegate(method: "textField(_:shouldChangeCharactersIn:replacementString:)")
    }

    /// Like `backspace()`; returns `.refusedByDelegate` if the delegate vetoed the deletion.
    @discardableResult
    public func backspaceOrThrow() throws -> FleetInteractionOutcome {
        guard isFirstResponder else {
            throw FleetFailure(kind: .invalidSetup, action: "backspace", target: "UITextField",
                               state: "the text field is not first responder",
                               reason: "Could not edit UITextField: Must start editing the text field before backspaces can be performed.")
        }
        let range = Fleet.TextEditing.backspaceRange(in: text ?? "", selection: Fleet.TextEditing.selectedRange(in: self))
        guard shouldChange(range, replacement: "") else {
            return .refusedByDelegate(method: "textField(_:shouldChangeCharactersIn:replacementString:)")
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
            throw FleetFailure(kind: .invalidSetup, action: "backspace all", target: "UITextField",
                               state: "the text field is not first responder",
                               reason: "Could not edit UITextField: Must start editing the text field before backspaces can be performed.")
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

/// Forwards every delegate message to the real delegate while remembering whether `textFieldShouldBeginEditing(_:)` returned `false`,
/// so a veto can be told apart from other focus failures without dispatching the callback a second time.
@MainActor
private final class BeginEditingVetoRecorder: NSObject, UITextFieldDelegate {
    private weak var target: (UITextFieldDelegate)?
    private(set) var vetoed = false
    private(set) var endVetoed = false

    init(wrapping target: UITextFieldDelegate?) {
        self.target = target
    }

    @objc func textFieldShouldBeginEditing(_ tf: UITextField) -> Bool {
        let result = target?.textFieldShouldBeginEditing?(tf) ?? true
        if !result { vetoed = true }
        return result
    }

    @objc func textFieldShouldEndEditing(_ tf: UITextField) -> Bool {
        let result = target?.textFieldShouldEndEditing?(tf) ?? true
        if !result { endVetoed = true }
        return result
    }

    override func responds(to selector: Selector!) -> Bool {
        if selector == #selector(UITextFieldDelegate.textFieldShouldBeginEditing(_:)) || selector == #selector(UITextFieldDelegate.textFieldShouldEndEditing(_:)) { return target?.responds(to: selector) ?? false }
        return super.responds(to: selector) || (target?.responds(to: selector) ?? false)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        target?.responds(to: selector) == true ? target : super.forwardingTarget(for: selector)
    }
}

#endif
