# UINavigationBar

Platforms: iOS, tvOS

## Methods

### `tapTopItem(withTitle:)`

```swift
func tapTopItem(withTitle title: String)
```

Searches the navigation bar's `topItem` for a bar button item whose title equals `title` and taps it, firing its action.

**Raises** a `Fleet.NavBarError` (`FleetError`) if:

- the navigation bar has no items,
- no item has the given title, or
- the item's action is not set up correctly.

## Example

```swift
navigationController.navigationBar.tapTopItem(withTitle: "Done")
```
