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
func enter(text: String)
```

Starts editing, types `text`, and stops editing.

**Raises** if the textField is hidden, is not enabled, cannot become first responder, or cannot resign first responder.

### `startEditing()`

```swift
func startEditing()
```

Makes the textField first responder. Calls the delegate's should-begin and did-begin editing methods.

**Raises** if the textField is hidden, is not enabled, or cannot become first responder. The textField must be in a window's view hierarchy.

### `stopEditing()`

```swift
func stopEditing()
```

Resigns first responder. Calls the delegate's should-end and did-end editing methods.

**Raises** if the textField is not first responder or fails to resign.

### `type(text:)`

```swift
func type(text newText: String)
```

Appends `newText` one character at a time. `textField(_:shouldChangeCharactersIn:replacementString:)` is called once per character.

**Raises** if the textField is not first responder.

### `paste(text:)`

```swift
func paste(text textToPaste: String)
```

Appends `textToPaste` as one change. `textField(_:shouldChangeCharactersIn:replacementString:)` is called once for the whole string.

**Raises** if the textField is not first responder.

### `backspace()`

```swift
func backspace()
```

Removes the last character, calling the delegate as a user's backspace would.

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

- Methods raise Objective-C exceptions, not Swift errors. Do not use `try`. See the [FAQ](FAQ.md#why-does-fleet-raise-exceptions-and-how-should-i-handle-them).
- The textField must be in the key window's hierarchy to become first responder.
- These helpers dispatch the editing events programmatically. They do not prove that the system keyboard appears or that a user could reach the control.
