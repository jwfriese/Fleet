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
