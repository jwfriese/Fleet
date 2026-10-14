# UITextField

Platforms: iOS only

All methods raise a `Fleet.TextFieldError` (`FleetError`) on failure.

## Methods

| Method | Summary |
| --- | --- |
| [`enter(text:)`](#entertext) | `startEditing()`, `type(text:)`, then `stopEditing()`. |
| [`startEditing()`](#startediting) | Gives the textField first responder focus. |
| [`stopEditing()`](#stopediting) | Removes first responder focus. |
| [`type(text:)`](#typetext) | Types text one character at a time. |
| [`paste(text:)`](#pastetext) | Inserts text as a single change. |
| [`backspace()`](#backspace) | Deletes the last character. |
| [`backspaceAll()`](#backspaceall) | Deletes every character, one backspace at a time. |
| [`clearText()`](#cleartext) | Clears the field as the clear button does. |

Delegate callbacks, notifications, and control events fire in the order UIKit uses.

### `enter(text:)`

```swift
@discardableResult
func enter(text: String) -> Bool
```

Starts editing, types `text`, and stops editing.

**Raises** if the textField is hidden, is not enabled, cannot become first responder, or cannot resign first responder.

### `startEditing()`

```swift
@discardableResult
func startEditing() -> Bool
```

Makes the textField first responder. Calls the delegate's should-begin and did-begin editing methods.

**Raises** if the textField is hidden, is not enabled, or cannot become first responder. The textField must be in a window's view hierarchy.

### `stopEditing()`

```swift
@discardableResult
func stopEditing() -> Bool
```

Resigns first responder. Calls the delegate's should-end and did-end editing methods.

**Raises** if the textField is not first responder or fails to resign.

### `type(text:)`

```swift
func type(text newText: String)
```

Types `newText` at the selection one character at a time. `textField(_:shouldChangeCharactersIn:replacementString:)` is called once per character.

**Raises** if the textField is not first responder.

### `paste(text:)`

```swift
func paste(text textToPaste: String)
```

Pastes `textToPaste` at the selection as one change. `textField(_:shouldChangeCharactersIn:replacementString:)` is called once for the whole string.

**Raises** if the textField is not first responder.

### `backspace()`

```swift
func backspace()
```

Removes the selection, or the composed character before the caret, calling the delegate as a user's backspace would.

**Raises** if the textField is not first responder.

### `backspaceAll()`

```swift
func backspaceAll()
```

Calls `backspace()` once per character.

**Raises** if the textField is not first responder.

### `clearText()`

```swift
func clearText()
```

Clears all text, calling the delegate's `textFieldShouldClear(_:)`. Text is cleared even without a delegate.

**Raises** if the field is hidden or not enabled, or if its `clearButtonMode` makes the clear button unavailable (`.never`; `.whileEditing` when not editing; `.unlessEditing` when editing).

## Example

```swift
let controller = getControllerUnderTest() as? ControllerUnderTest
controller?.textField.enter(text: "text")
```

## Notes

- The plain methods raise Objective-C exceptions, not Swift errors; do not use `try` with them. The `...OrThrow` forms below report recoverable `FleetFailure` errors. See the [FAQ](FAQ.md#why-does-fleet-raise-exceptions-and-how-should-i-handle-them).
- The textField must be in the key window's hierarchy to become first responder.
- These helpers dispatch the editing events programmatically. They do not prove that the system keyboard appears or that a user could reach the control.

### Recoverable failures

`enterOrThrow(text:)`, `startEditingOrThrow()`, `stopEditingOrThrow()`, `typeOrThrow(text:)`, `pasteOrThrow(text:)`,
`backspaceOrThrow()`, and `backspaceAllOrThrow()` perform the same interaction as their plain counterparts but throw a
`FleetFailure` instead of raising, and return a `FleetInteractionOutcome`. `.unavailableInteraction` means the control is
hidden, disabled, or otherwise not editable; `.invalidSetup` means it is not in a window or is not first responder when
required. A delegate veto is not an error: the call returns `.refusedByDelegate(method:)` (for `typeOrThrow` and
`backspaceAllOrThrow`, if any step was vetoed) and the forbidden edit does not happen. The plain methods call these and
raise the failure's reason as before.

## Selection, Unicode, and refusal semantics

These helpers are iOS only (not available on tvOS) and act on the control's actual selection.

- **Ranges.** Delegates receive UTF-16 `NSRange` values, as they do from UIKit. `type(text:)` and
  `paste(text:)` replace the current selection or insert at the caret; `backspace()` deletes the
  selection or, with only a caret, the whole composed character sequence before it (an emoji, a
  joined emoji sequence, or a letter with combining marks goes in one backspace). A `type(text:)`
  character is a grapheme cluster, so such sequences produce one delegate callback.
- **Refused changes.** If `textField(_:shouldChangeCharactersIn:replacementString:)` returns `false`, the text and
  selection are untouched. When `type(text:)` is refused for a character it moves on to the next one.
  `backspace()` at the start of the text asks the delegate about an empty range at location 0 and changes nothing.
- **`backspaceAll()`** first moves the caret to the end of the text (collapsing any selection), then
  backspaces once per character.
- **Refused editing.** `textFieldShouldBeginEditing(_:)` and `textFieldShouldEndEditing(_:)` are consulted exactly once, by UIKit, during
  `becomeFirstResponder()`/`resignFirstResponder()`. A veto is not an error: `startEditing()` and
  `stopEditing()` return `false` (the return value is discardable) and focus is unchanged. `enter(text:)` stops
  before typing when beginning is refused, and returns `false` after typing when ending is refused (the
  text field stays first responder). Failing to become first responder because the text field is not in a window still raises.
- **Keyboard notifications.** After a successful focus change Fleet posts `keyboardWillShow`/`DidShow` (or
  `WillHide`/`DidHide`) notifications with no `object` or `userInfo`. They are simulated for observers; Fleet
  does not present, measure, or dismiss a keyboard, and nothing is posted for a refused or no-op change.
  Fleet's own suites use a local input view; real keyboard presentation needs separate coverage.
