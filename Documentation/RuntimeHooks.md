# Runtime hooks

Fleet installs Objective-C method exchanges when its library loads. Each Objective-C category's `+load` calls a nonisolated Swift installer, which only exchanges method implementations; the hooks themselves, and any state they keep, run on the main actor. Activation is automatic and unconditional for this major release: Fleet does not toggle hooks per test, and importing Fleet is not required to be opt-in. Fleet's own tests and the Git-pinned external consumers (`script/check-distribution`) verify activation on iOS and tvOS.

If a hooked selector is missing at load time, `Fleet.swizzle` raises a `Fleet.InternalError` naming the class and selectors rather than continuing with a partly installed runtime.

## Inventory

| Hook (class, selector) | Installed from | State it owns | Behavioral effect | Probe |
| --- | --- | --- | --- | --- |
| `UIViewController.viewDidLoad` | `UIViewController+Fleet.m` | Associated count of `viewDidLoad` calls per controller | Counts loads so storyboard binding can reject an already-loaded controller | `RuntimeHooksSpec`, consumer `testViewDidLoadHookRejectsBindingAnAlreadyLoadedController` |
| `UIViewController.present(_:animated:completion:)` | `UIViewController+Fleet.m` | None | Forces `animated: false` for every presentation in the process | `RuntimeHooksSpec`, consumer `testRuntimeHooksPresentSynchronously` |
| `UIViewController.dismiss(animated:completion:)` | `UIViewController+Fleet.m` | None | Forces `animated: false` for every dismissal in the process | `RuntimeHooksSpec` |
| `UINavigationController.pushViewController(_:animated:)` | `UINavigationController+Fleet.m` | None | Pushes synchronously without animation and loads the pushed view | `RuntimeHooksSpec`, consumer `testHostedNavigationPushAndPop` |
| `UINavigationController.popViewController(animated:)`, `popToViewController(_:animated:)`, `popToRootViewController(animated:)` | `UINavigationController+Fleet.m` | None | Pops synchronously without animation | `RuntimeHooksSpec` |
| `UIStoryboard.instantiateViewController(withIdentifier:)` | `UIStoryboard+Fleet.m` | Main-actor storyboard binding map | Returns a bound or mocked instance when one is registered for the identifier | Storyboard specs, consumer `testCompiledStoryboardMetadataAndBinding` |
| `UIAlertAction.setHandler:` (**private**) | `UIAlertAction+Fleet.m` | Associated handler block per action | Remembers the handler so `tapAlertAction(withTitle:)` can run it; UIKit still receives it | `RuntimeHooksSpec`, consumer `testAlertHandlerCaptureAndDispatch` |

The presentation, dismissal, and navigation hooks are process-wide. They change the timing of real production code under test, which is the point of the library, but they also apply to code that never goes through a Fleet helper.

## Unsupported configurations

- Handler capture uses private selectors. If UIKit stops calling the hooked selector, alert actions report no handler, and `tapAlertAction(withTitle:)` dismisses an action that has no captured handler without running anything. An action created without a handler is indistinguishable from one whose handler was not captured.
- Fleet does not add any new private-handler hook to support further UIKit types, such as `UIContextualAction` or menu elements. The former `UITableViewRowAction` handler hook was removed in this major release (see [UITableView](UITableView.md#migrating-from-selectcellaction)). Invoke the handlers you own directly.
- Hooks are installed once per process. Statically linking Fleet in a way that drops the Objective-C categories (for example without `-ObjC`) leaves them uninstalled; the dynamic SwiftPM product used by the supported route does not.
- Hosted tests must run on the main thread; the instance hooks do not make UIKit thread-safe.
