## UIBarButtonItem

Fleet provides helpers for `UIBarButtonItem` similar to those provider for `UIButton`. Here is the normal
flow for testing taps on UIBarButtonItem objects:

```swift
// Problematic for several reasons:
// 1) Not intuitive -- especially for those new to iOS
// 2) Many points of failure with no indication of what went wrong. Maybe I did not
//    link my target or action correctly? Or maybe the implementation of the action is
//    wrong?
let someBarButtonItem = viewControllerWithNavBar.rightBarButton
someBarButtonItem.target?.perform(someBarButtonItem.action, with: someBarButtonItem)
```

Instead, you can use the Fleet extension `tap` like so:

```swift
// Simple to understand, and also throws an error when something goes wrong not
// related to the action implementation:
// 1) target improperly hooked up
// 2) action improperly hooked up
// 3) The button is not enabled
let someBarButtonItem = viewControllerWithNavBar.rightBarButton
try! someBarButtonItem.tap()
```

