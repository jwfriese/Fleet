# UIBarButtonItem

Platforms: iOS, tvOS

## Methods

### `tap()`

```swift
func tap()
```

Mimics a user tap.

`tap` sends the action with `UIApplication.sendAction(_:to:from:for:)`, as UIKit does: the item is the sender,
and an item with a nil target dispatches up the responder chain from the first responder in the key window
(a view or view controller). Items created with `UIBarButtonItem(primaryAction:)` run their action exactly once
(iOS and tvOS 16 or later; earlier systems raise a `Fleet.BarButtonItemError`).

A `Fleet.BarButtonItemError` is raised when the item is disabled, when it only presents a menu (iOS), when it
has neither action nor primary action, when it has no target and no responder in the chain handles the action,
or when its explicit target does not respond to the action. Physical hit testing and menu presentation are not
exercised.

**Notes**

- Errors raised by your action's implementation are not Fleet errors.

## Example

```swift
let item = viewControllerWithNavBar.navigationItem.rightBarButtonItem!
item.tap()
```
