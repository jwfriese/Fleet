# UITextView

Platforms: iOS only

All methods raise a `Fleet.TextViewError` (`FleetError`) on failure.

## Methods

| Method | Summary |
| --- | --- |
| [`enter(text:)`](#entertext) | `startEditing()`, `type(text:)`, then `stopEditing()`. |
| [`startEditing()`](#startediting) | Gives the textView first responder focus. |
| [`stopEditing()`](#stopediting) | Removes first responder focus. |
| [`type(text:)`](#typetext) | Types text one character at a time. |
| [`paste(text:)`](#pastetext) | Inserts text as a single change. |
| [`backspace()`](#backspace) | Deletes the last character. |
| [`backspaceAll()`](#backspaceall) | Deletes every character, one backspace at a time. |

Delegate callbacks and notifications fire in the order UIKit uses.

### `enter(text:)`

```swift
@discardableResult
func enter(text: String) -> Bool
```

Starts editing, types `text`, and stops editing.

**Raises** if `startEditing()`, `type(text:)`, or `stopEditing()` raises.

### `startEditing()`

```swift
@discardableResult
func startEditing() -> Bool
```

Makes the textView first responder. Calls the delegate's should-begin and did-begin editing methods.

**Raises** if the textView does not allow user interaction, is hidden, is not selectable, is not editable, or cannot become first responder. The textView must be in a window's view hierarchy.

### `stopEditing()`

```swift
@discardableResult
func stopEditing() -> Bool
```

Resigns first responder. Calls the delegate's should-end and did-end editing methods.

**Raises** if the textView is not first responder or fails to resign.

### `type(text:)`

```swift
func type(text newText: String)
```

Types `newText` at the selection one character at a time. `textView(_:shouldChangeTextIn:replacementText:)` is called once per character.

**Raises** if the textView is not first responder.

### `paste(text:)`

```swift
func paste(text textToPaste: String)
```

Pastes `textToPaste` at the selection as one change. `textView(_:shouldChangeTextIn:replacementText:)` is called once for the whole string.

**Raises** if the textView is not first responder.

### `backspace()`

```swift
func backspace()
```

Removes the selection, or the composed character before the caret, calling the delegate as a user's backspace would.

**Raises** if the textView is not first responder.

### `backspaceAll()`

```swift
func backspaceAll()
```

Calls `backspace()` once per character.

**Raises** if the textView is not first responder.

## Example

```swift
let controller = getControllerUnderTest() as? ControllerUnderTest
controller?.textView.enter(text: "text")
```

## Notes

- Methods raise Objective-C exceptions, not Swift errors. Do not use `try`. See the [FAQ](FAQ.md#why-does-fleet-raise-exceptions-and-how-should-i-handle-them).
- The textView must be in the key window's hierarchy to become first responder.
- These helpers dispatch the editing events programmatically. They do not prove that the system keyboard appears or that a user could reach the control.

## Selection, Unicode, and refusal semantics

These helpers are iOS only (not available on tvOS) and act on the control's actual selection.

- **Ranges.** Delegates receive UTF-16 `NSRange` values, as they do from UIKit. `type(text:)` and
  `paste(text:)` replace the current selection or insert at the caret; `backspace()` deletes the
  selection or, with only a caret, the whole composed character sequence before it (an emoji, a
  joined emoji sequence, or a letter with combining marks goes in one backspace). A `type(text:)`
  character is a grapheme cluster, so such sequences produce one delegate callback.
- **Refused changes.** If `textView(_:shouldChangeTextIn:replacementText:)` returns `false`, the text and
  selection are untouched. When `type(text:)` is refused for a character it moves on to the next one.
  `backspace()` at the start of the text asks the delegate about an empty range at location 0 and changes nothing.
- **`backspaceAll()`** first moves the caret to the end of the text (collapsing any selection), then
  backspaces once per character.
- **Refused editing.** `textViewShouldBeginEditing(_:)` and `textViewShouldEndEditing(_:)` are consulted exactly once, by UIKit, during
  `becomeFirstResponder()`/`resignFirstResponder()`. A veto is not an error: `startEditing()` and
  `stopEditing()` return `false` (the return value is discardable) and focus is unchanged. `enter(text:)` stops
  before typing when beginning is refused, and returns `false` after typing when ending is refused (the
  text view stays first responder). Failing to become first responder because the text view is not in a window still raises.
- **Keyboard notifications.** After a successful focus change Fleet posts `keyboardWillShow`/`DidShow` (or
  `WillHide`/`DidHide`) notifications with no `object` or `userInfo`. They are simulated for observers; Fleet
  does not present, measure, or dismiss a keyboard, and nothing is posted for a refused or no-op change.
  Fleet's own suites use a local input view; real keyboard presentation needs separate coverage.
