## UINavigationController

When firing code in test that would cause a navigation controller to either push or pop a view controller, Fleet forces the results of the view action to occur immediately. Your test code will not have to wait for the run-loop to assert your expectations.

```swift
let rootViewController = UIViewController()
let navigationController = UINavigationController(rootViewController: rootViewController)
let controllerToPush = UIViewController()

navigationController.pushViewController(controllerToPush, animated: true)

// You can test that pushing the controller has successfully occurred immediately after executing it.
expect(navigationController.topViewController).to(beIdenticalTo(controllerToPush))
expect(navigationController.visibleViewController).to(beIdenticalTo(controllerToPush))

navigationController.popViewControllerAnimated(true)

// Likewise with popping from the nav stack -- as soon as you call the code, you can assert on the results.
expect(navigationController.topViewController).to(beIdenticalTo(rootViewController))
expect(navigationController.visibleViewController).to(beIdenticalTo(rootViewController))
```

The behavior is similar for `popToViewController(_:animated:)` and `popToRootViewControllerAnimated(_:)`
