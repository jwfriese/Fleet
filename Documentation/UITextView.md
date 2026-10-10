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
func enter(text: String)
```

Starts editing, types `text`, and stops editing.

**Raises** if `startEditing()`, `type(text:)`, or `stopEditing()` raises.

### `startEditing()`

```swift
func startEditing()
```

Makes the textView first responder. Calls the delegate's should-begin and did-begin editing methods.

**Raises** if the textView does not allow user interaction, is hidden, is not selectable, is not editable, or cannot become first responder. The textView must be in a window's view hierarchy.

### `stopEditing()`

```swift
func stopEditing()
```

Resigns first responder. Calls the delegate's should-end and did-end editing methods.

**Raises** if the textView is not first responder or fails to resign.

### `type(text:)`

```swift
func type(text newText: String)
```

Appends `newText` one character at a time. `textView(_:shouldChangeTextIn:replacementText:)` is called once per character.

**Raises** if the textView is not first responder.

### `paste(text:)`

```swift
func paste(text textToPaste: String)
```

Appends `textToPaste` as one change. `textView(_:shouldChangeTextIn:replacementText:)` is called once for the whole string.

**Raises** if the textView is not first responder.

### `backspace()`

```swift
func backspace()
```

Removes the last character, calling the delegate as a user's backspace would.

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
