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

- Handler capture uses private selectors. If UIKit stops calling the hooked selector, the legacy `tapAlertAction(withTitle:)` and `tapAlertActionOrThrow(withTitle:)` still dismiss an action that has no captured handler without running anything (retained legacy contract; they dismiss and invoke a captured handler, and prove no physical interaction).
- `Fleet.AlertHandlerCapture` records what was observed: `.observedHandler` (setter saw a non-nil handler), `.observedNil` (setter saw nil), `.unobserved` (setter never seen, so an intentionally absent handler cannot be told from an uncaptured one), and `.unavailable` (the private `setHandler:` selector was missing at load; Fleet records this instead of raising from `+load` for this path, and installs no hook). `tapAlertActionStrictly(withTitle:) async throws` dismisses and runs a handler only for `.observedHandler`, reports `.dismissedWithoutHandler` for `.observedNil`, and throws `FleetFailure` (`.invalidSetup`) before dismissing for `.unobserved`/`.unavailable`. It is async and returns only after UIKit's dismissal completion has run the handler, so its outcome reports completed execution, not scheduling. Detection is not complete: a handler is never assumed to work from the action's presence or a successful dismissal. For behavior interception cannot establish, call an application-owned command directly or use an XCUITest.
- Fleet does not add any new private-handler hook to support further UIKit types, such as `UIContextualAction` or menu elements. The former `UITableViewRowAction` handler hook was removed in this major release (see [UITableView](UITableView.md#migrating-from-selectcellaction)). Invoke the handlers you own directly.
- Hooks are installed once per process. Statically linking Fleet in a way that drops the Objective-C categories (for example without `-ObjC`) leaves them uninstalled; the dynamic SwiftPM product used by the supported route does not.
- Hosted tests must run on the main thread; the instance hooks do not make UIKit thread-safe.

## Hosting policy

The presentation, dismissal and navigation hooks above are the `legacy` policy, which remains the default. A process can instead start with `preserve-timing`, which does not install them: production `present`, `dismiss`, `push`, `pop` calls forward UIKit's own animated arguments, timing, delegate ordering and lazy view loading.

- Select it with the `FLEET_HOSTING_POLICY` environment variable (`legacy` or `preserve-timing`) in the test plan, scheme or launch environment of the test host process. It is read once, before any `+load` chooses hooks, and never changes afterwards. Do not set it per test; the hooks are not installed or removed around contexts.
- An unset or empty value resolves to `legacy`. Any other value raises `FleetInvalidHostingPolicy` at load, naming the accepted values; there is no fallback.
- `Fleet.hostingPolicy` reports the active policy read-only so a consumer can verify its setup.
- Under `preserve-timing`, the retained hooks are exactly: `UIViewController.viewDidLoad` (load counting for storyboard binding), `UIStoryboard.instantiateViewController(withIdentifier:)` (binding/mocking) and the private `UIAlertAction.setHandler:` capture. Fleet is therefore not runtime-free in this mode; extracting a hook-free product was not needed for the timing contract.
- Context setup, explicit readiness and the nonanimated cleanup performed by `Fleet.withContext` remain documented, intentional operations under both policies, and do not depend on these hooks. Code that relied on synchronous presentation must wait for the state it asserts with bounded waits under `preserve-timing`.

### Validating the hosting policy

- `script/check-distribution` runs the public-package consumer twice per platform in fresh test-host processes: once with the default (legacy) policy and once with `FLEET_HOSTING_POLICY=preserve-timing` set through the launch environment (`TEST_RUNNER_FLEET_HOSTING_POLICY`). The consumer asserts the active `Fleet.hostingPolicy`, forwarded animated arguments, delegate/lifecycle/completion ordering and, for an offscreen push, whether the pushed view loads eagerly.
- The native suite can be run under preserve-timing with `TEST_RUNNER_FLEET_HOSTING_POLICY=preserve-timing script/test all`. Tests that pin the legacy contract (synchronous, nonanimated, eagerly loaded navigation, and comparisons against the `fleet_` selectors that hold UIKit's code only when the hooks are installed) skip themselves under preserve-timing.
- `FleetTestContext.waitForTransitionsToFinish` inspects the presentation chain, navigation stacks and container children (tabs). Controllers whose views are not in a window, such as a deselected tab, are not awaited because UIKit does not advance their animated transitions until they return on screen.
- The generated consumer project also has a `Baseline-<platform>` scheme whose test bundle links no Fleet product, so its fresh host process runs UIKit with no Fleet hooks. All three processes run the same UIKit-only scenario (`HostingTraceScenario.swift`: offscreen animated push, then animated push, pop, present and dismiss with completions) and record the order of lifecycle, navigation-delegate and completion callbacks, the forwarded animated arguments and whether the offscreen pushed view loaded. `script/check-distribution` requires the preserve-timing trace to equal the baseline trace exactly (relative order, not elapsed time), and requires the legacy trace to keep its documented contract: nonanimated arguments and an eagerly loaded offscreen push.
- Not covered: invalid startup values are not exercised in a fresh negative-launch process.
