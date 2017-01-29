## UISwitch

Given you have some UIViewController that looks like this:
```swift
class ControllerUnderTest: UIViewController {
	@IBOutlet weak var someSwitch: UISwitch?

// rest of code here
// ...
}
```

When you want to test the behavior that backs the view controller's `switch`, rather than doing something like:

```swift
let controller = getControllerUnderTest() as? ControllerUnderTest
controller?.someSwitch?.setOn(false, animated: false)
controller?.someSwitch?.sendActions(for: .valueChanged)
```

you can use Fleet's extension `flip` like so:

```swift
let controller = getControllerUnderTest() as? ControllerUnderTest
try! controller?.someSwitch?.flip()
```

`flip` on `UISwitch` toggles the switch without animating it, doing the work of setting the switch with the
correct value and ensuring that all relevant control events get sent in exactly the order that UIKit sends
them in production code.

Additionally, it throws an error in the following situations:
1) The `UISwitch` is not visible
2) The `UISwitch` is not enabled
3) User interaction is disabled for the `UISwitch`

By contrast, calling the `setOn(_, animated:)` method yourself will give you no indication of whether a user
could even have interacted with that object in the first place.
