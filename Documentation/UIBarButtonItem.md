# UIBarButtonItem

Platforms: iOS, tvOS

## Methods

### `tap()`

```swift
func tap()
```

Mimics a user tap by performing the item's `action` on its `target`.

**Raises** a `Fleet.BarButtonItemError` (`FleetError`) if the item:

- is not enabled,
- has no `target`, or
- has no `action`.

**Notes**

- Errors raised by your action's implementation are not Fleet errors.

## Example

```swift
let item = viewControllerWithNavBar.navigationItem.rightBarButtonItem!
item.tap()
```
