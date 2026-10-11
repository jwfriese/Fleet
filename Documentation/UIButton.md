# UIButton

Platforms: iOS, tvOS

## Methods

### `tap()`

```swift
func tap()
```

Mimics a user tap. Sends `.touchDown`, then `.touchUpInside`.

**Raises** a `Fleet.ButtonError` (`FleetError`) if the button:

- does not allow user interaction,
- is not enabled, or
- is hidden.

**Notes**

- Handlers registered any supported way run exactly once per `tap`: target/action pairs added with `addTarget(_:action:for:)`, `UIAction`s added with `addAction(_:for:)`, and the button's `primaryAction` (`UIButton(primaryAction:)`). A button that presents a menu as its primary action (`showsMenuAsPrimaryAction`, iOS only) is rejected with a `Fleet.ButtonError` instead of being tapped, since a real tap opens the menu and sends no control events; invoke the handler of the menu element you want directly.
- `sendActions(for:)` performs none of these checks, so it can fire events the user could not.
- Physical hit testing (for example, an overlapping view) is not simulated.

## Example

```swift
let controller = getControllerUnderTest() as? ControllerUnderTest
controller?.button?.tap()
```
