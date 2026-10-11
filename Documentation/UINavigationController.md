# UINavigationController

Platforms: iOS, tvOS

## Behavior

Fleet replaces animated stack changes with non-animated `setViewControllers(_:animated:)` calls, so the stack can be asserted immediately after the call. A pushed controller's view is loaded.

Applies to:

- `pushViewController(_:animated:)`
- `popViewController(animated:)`
- `popToViewController(_:animated:)`
- `popToRootViewController(animated:)`

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
