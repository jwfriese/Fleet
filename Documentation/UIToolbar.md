# UIToolbar

Platforms: iOS only

## Methods

### `tapItem(withTitle:)`

```swift
func tapItem(withTitle title: String)
```

Taps the toolbar item whose title equals `title`, firing its action.

**Raises** a `Fleet.ToolbarError` (`FleetError`) if no item has that title, if more than one item has it (nothing is tapped; give items distinct titles), or the item's action is not set up correctly.

### `tapItemOrThrow(withTitle:)`

The recoverable form: it throws a `FleetFailure` (`.invalidSetup` without items, `.invalidInput` for a missing or ambiguous title, otherwise the item's own `tapOrThrow()` failure) instead of raising.

## Example

```swift
let toolbar = navigationController.toolbar!
toolbar.tapItem(withTitle: "Some Item")
```
