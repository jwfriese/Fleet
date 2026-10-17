# UIAlertController

Platforms: iOS, tvOS

## Methods

### `tapAlertAction(withTitle:)`

```swift
func tapAlertAction(withTitle title: String)
```

Fires the handler of the alert action whose title equals `title`.

The alert is dismissed first (without animation) and the action's handler runs in the dismissal completion, so the
handler observes the presenting controller as the topmost controller. An action created without a handler is
simply dismissed.

The `tapAlertAction(withTitle:)` method raises a `Fleet.AlertError` when:
1) no action with the given title exists on the alert,
2) more than one action has the title (Fleet never guesses; give actions distinct titles or invoke the handler you own),
3) the matching action is disabled (`isEnabled == false`), or
4) the alert is not presented.

In every case no handler runs and the alert is left as it was.

`tapAlertActionOrThrow(withTitle:)` reports the same conditions as a thrown `FleetFailure` instead of raising:
`.invalidInput` for a missing or ambiguous title and `.unavailableInteraction` for a disabled action or an alert that is not presented.

## Example

```swift
let alert = UIAlertController(title: "Some Alert", message: nil, preferredStyle: .alert)
alert.addAction(UIAlertAction(title: "Some Action", style: .default) { _ in
    // handler under test
})

alert.tapAlertAction(withTitle: "Some Action")
```
