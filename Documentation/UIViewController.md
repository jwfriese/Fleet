# UIViewController

Platforms: iOS, tvOS

## Behavior

Fleet disables animation of presentation and dismissal, so results can be asserted without waiting on an animation.

Applies to:

- `present(_:animated:completion:)`
- `dismiss(animated:completion:)`

Fleet does not force transitions to complete synchronously. If an assertion is flaky, wait for the state with a bounded poll. See the [FAQ](FAQ.md#does-fleet-do-lots-of-swizzling-to-provide-its-features).

Present from a view controller that is in the key window. See [the FAQ](FAQ.md#why-should-i-make-sure-all-uiviewcontroller-tests-happen-in-a-uiwindow).

## Example

```swift
let bottom = UIViewController()
let top = UIViewController()
Fleet.setAsAppWindowRoot(bottom)

bottom.present(top, animated: true, completion: nil)
expect(bottom.presentedViewController).toEventually(beIdenticalTo(top))
expect(top.presentingViewController).toEventually(beIdenticalTo(bottom))

bottom.dismiss(animated: true, completion: nil)
expect(bottom.presentedViewController).toEventually(beNil())
```

## Finding what is on screen

`FLTScreen` has two lookups with distinct meanings:

- `topmostViewController` is the **visible content**. Starting at the window's root, it follows presentations, then descends into a navigation controller's `topViewController` and a tab bar controller's `selectedViewController`, repeating until neither applies. An empty navigation controller or tab bar controller is returned itself.
- `topmostContainer` is the end of the **presentation chain** without descending into navigation or tab children, so it returns the `UINavigationController` or `UITabBarController` that hosts the visible content.

Split view controllers and custom container controllers are **not** traversed: they are returned as they are, and their children must be reached explicitly.

For waiting on presentation and dismissal state, see the behavior notes above.
