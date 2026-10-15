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
- no item has the given title,
- more than one item has the title, left and right items counted together (nothing is tapped; give the items distinct titles), or
- the item's action is not set up correctly.

### `tapTopItemOrThrow(withTitle:)`

```swift
func tapTopItemOrThrow(withTitle title: String) throws
```

The recoverable form: it throws a `FleetFailure` (`.invalidSetup` without a top item, `.invalidInput` for a missing or ambiguous title, otherwise the item's own `tapOrThrow()` failure) instead of raising.

## Example

```swift
navigationController.navigationBar.tapTopItem(withTitle: "Done")
```
