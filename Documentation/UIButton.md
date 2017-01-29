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
controller?.button.sendActions(for: .touchDown)
controller?.button.sendActions(for: .touchUpInside)
```

you can use Fleet's extension `tap` like so:

```swift
let controller = getControllerUnderTest() as? ControllerUnderTest
try! controller?.button.tap()
```

`tap` on `UIButton` mimics a tap on the button, ensuring that all relevant control events get sent,
in the same order that UIKit sends them.

Additionally, it throws a `Fleet.ButtonError` in the following situations:
1) The `UIButton` is not visible.
2) The `UIButton` is not enabled.
3) The `UIButton` does not allow user interaction.

By contrast, calling `sendActions(for: .touchUpInside)` and `sendActions(for: .touchDown)` yourself will give
you no indication of whether a user could even have interacted with that object in the first place. It will
fire events in-test that could not have been fired by the production code were the button in the same state.
