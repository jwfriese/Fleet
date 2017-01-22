## UIButton

Given you have some UIViewController that looks like this:
```swift
class ControllerUnderTest: UIViewController {
	@IBOutlet weak var button: UIButton?

// rest of code here
// ...
}
```

When you want to test the behavior that backs the view controller's `button`, rather than doing something like:

```swift
let controller = getControllerUnderTest() as? ControllerUnderTest
controller?.button.sendActions(for: .touchUpInside)
```

you can use Fleet's extension `tap` like so:

```swift
let controller = getControllerUnderTest() as? ControllerUnderTest
let _ = controller?.button.tap()
```

`tap` on `UIButton` mimics a tap on the button, ensuring that all relevant control events get sent.

Additionally, it returns a `FleetError` optional that will contain an error in the following situations:
1) The `UIButton` is not visible
2) The `UIButton` is not enabled

By contrast, calling `sendActions(for: .touchUpInside)` yourself will give you no indication of whether a user
could even have interacted with that object in the first place. It will fire events in-test that could not have been fired
by the production code were the button in the same state.
