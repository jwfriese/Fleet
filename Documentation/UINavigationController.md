# UINavigationController

Platforms: iOS, tvOS

## Behavior

Fleet turns off animation for `pushViewController(_:animated:)`, `popViewController(animated:)`, `popToViewController(_:animated:)` and `popToRootViewController(animated:)`. Each call is forwarded to UIKit with `animated: false`, so UIKit itself mutates the stack, validates arguments, and produces return values. Fleet does not rebuild the stack. As a result, the stack and `topViewController` are updated, and a pushed view controller is loaded, by the time the call returns.

## Example

```swift
let root = UIViewController()
let navigationController = UINavigationController(rootViewController: root)
let pushed = UIViewController()

navigationController.pushViewController(pushed, animated: true)
expect(navigationController.topViewController).to(beIdenticalTo(pushed))

navigationController.popViewController(animated: true)
expect(navigationController.topViewController).to(beIdenticalTo(root))
```

Return values match UIKit: popping a root-only or empty stack returns `nil`, and `popToViewController(_:animated:)` / `popToRootViewController(animated:)` return the controllers removed, in stack order.

### Delegate callbacks

`UINavigationControllerDelegate` `willShow` / `didShow` callbacks, like appearance callbacks, are UIKit's and may be delivered after the call returns when the transition runs in a hosted window. Assert on stack state immediately, but wait (with a bounded `toEventually` or an `XCTestExpectation`) for delegate and appearance callbacks. The order is `willShow` then `didShow`.

### Seeing the container and the visible content

`Fleet.getApplicationScreen()?.topmostViewController` returns the visible content (the navigation controller's `topViewController`), while `topmostContainer` returns the `UINavigationController` itself. See [FLTScreen](../Fleet/Screen/FLTScreen.swift).
