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

- `sendActions(for:)` performs none of these checks, so it can fire events the user could not.
- Physical hit testing (for example, an overlapping view) is not simulated.

## Example

```swift
let controller = getControllerUnderTest() as? ControllerUnderTest
controller?.button?.tap()
```
