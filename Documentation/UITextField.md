## UITextField

Instead of having to manually send text editing events yourself, you can now simply enter text into a text field using `enterText(_:)` on any `UITextField`. 

For example:
```swift
let textField = viewController.someTextField
textField.enterText("text")

// Any delegate attached to the text field will automatically receive all
// events that you would expect to receive had a real user interacted 
// with the text field. 
```

You can also get more granular control with the `enter()`, `leave()`, `typeText(_:)`, and `pasteText(_:)` methods. 

```swift
textField.enter()

// Sends should begin and did begin events to the delegate.
```

```swift
textField.leave()

// Sends should end and did end events to the delegate if textField previously
// had enter() called on it. 
```

```swift
textField.typeText("text")
textField.pasteText("text")

// Sends the appropriate editing changed methods to the delegate. The 
// difference between the two is that typeText(_:) triggers the 
// textField:shouldChangeCharactersInRange:replacementString: method for
// each character in the given string, while pasteText(_:) triggers it for the 
// entire given string. 
```

```swift
textField.clearText()

// Sends the appropriate shouldClearText methods to the delegate. 
```
