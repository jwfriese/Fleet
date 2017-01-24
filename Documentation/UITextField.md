## UITextField

Instead of having to manually send text editing events yourself, you can now simply enter text into a text field using `enter(text:)` on any `UITextField`.

For example, given you have some UIViewController that looks like this:
```swift
class ControllerUnderTest: UIViewController {
	@IBOutlet weak var textField: UITextField?

// rest of code here
// ...
}
```
When you want to enter some text into the controller's `textField`, simply do the following:

```swift
let controller = getControllerUnderTest() as? ControllerUnderTest
let _ = controller.textField?.enter(text: "text")

// Any delegate attached to the text view will automatically receive all
// events that you would expect to receive had a real user interacted
// with the text view. This includes:
//
// - the call to make the text field a first responder
// - should begin/did begin editing events
// - all the text change callbacks exactly as they would be received were a user to actually
//   input the text themselves
// - appropriate focus handoff callbacks in the case that another element had focus
// - should end/did end editing events
// - and of course, the text in the text field will update appropriately
//
```

You can also get more granular control with the `startEditing()`, `endEditing()`, `type(text:)`, `paste(text:)`, and `backspace()` methods.

```swift
let _ = textField.startEditing()

// Sends should begin and did begin events to the delegate.
```

```swift
let _ = textField.endEditing()

// Sends should end and did end events to the delegate if textField previously
// had startEditing() called on it.
```

```swift
let _ = textField.type(text: "text")
let _ = textField.paste(text: "text")

// Sends the appropriate editing changed methods to the delegate. The
// difference between the two is that type(text:) triggers the
// textField:shouldChangeCharactersInRange:replacementString: method for
// each character in the given string, while paste(text:) triggers it for the
// entire given string.
```

```swift
let _ = textField.backspace()

// Sends the appropriate methods to the delegate while removing the last character of content
// from the text field.
```

All the methods return `FleetError` error objects that communicate errors that occur when attempting to perform
the various operations. For example, the `UITextField.type(text:)` method will return an error when it is called
on a text field that does not have first responder focus.
