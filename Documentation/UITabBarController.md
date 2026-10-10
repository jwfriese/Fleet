# UITabBarController

Platforms: iOS, tvOS

## Methods

### `selectTab(withLabel:)`

```swift
func selectTab(withLabel labelText: String)
```

Selects the tab whose label equals `labelText`, calling the delegate methods UIKit calls in production.

### `selectTab(atIndex:)`

```swift
func selectTab(atIndex index: Int)
```

Selects the tab at `index`, with the same behavior as `selectTab(withLabel:)`.

## Example

```swift
tabBarController.selectTab(withLabel: "Tab Text")
tabBarController.selectTab(atIndex: 1)
```
