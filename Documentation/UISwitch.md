# UISwitch

Platforms: iOS only

## Methods

### `flip()`

```swift
func flip()
```

Toggles the switch without animation, then sends `.valueChanged` and `.touchUpInside`.

**Raises** a `Fleet.SwitchError` (`FleetError`) if the switch:

- does not allow user interaction,
- is not enabled, or
- is hidden.

**Notes**

- `setOn(_:animated:)` performs none of these checks, so it can change state the user could not.

## Example

```swift
let controller = getControllerUnderTest() as? ControllerUnderTest
controller?.someSwitch?.flip()
```
