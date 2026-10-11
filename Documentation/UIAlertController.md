# UIAlertController

Platforms: iOS, tvOS

## Methods

### `tapAlertAction(withTitle:)`

```swift
func tapAlertAction(withTitle title: String)
```

Fires the handler of the alert action whose title equals `title`.

**Raises** a `Fleet.AlertError` (`FleetError`) if the alert has no action with that title.

## Example

```swift
let alert = UIAlertController(title: "Some Alert", message: nil, preferredStyle: .alert)
alert.addAction(UIAlertAction(title: "Some Action", style: .default) { _ in
    // handler under test
})

alert.tapAlertAction(withTitle: "Some Action")
```
