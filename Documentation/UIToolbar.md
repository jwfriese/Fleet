# UIToolbar

Platforms: iOS only

## Methods

### `tapItem(withTitle:)`

```swift
func tapItem(withTitle title: String)
```

Taps the toolbar item whose title equals `title`, firing its action.

**Raises** a `Fleet.ToolbarError` (`FleetError`) if no item has that title or the item's action is not set up correctly.

## Example

```swift
let toolbar = navigationController.toolbar!
toolbar.tapItem(withTitle: "Some Item")
```
