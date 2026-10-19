# Scoped window hosting

`Fleet.withContext` gives a hosted test explicit ownership of its UI environment for its whole async lifetime, instead of relying on the global key-window lookup used by `Fleet.getApplicationScreen()` and `Fleet.setAsAppWindowRoot(_:)`.

```swift
// Borrow a window you already know (restored afterward):
try await Fleet.withContext(window: hostWindow) { context in
    try await context.setRoot(MyViewController())
    context.screen.topmostViewController // wraps the context's window
    try await context.waitUntil("title to load", timeout: 2) { label.text == "Ready" }
}

// Or create (and later dismantle) a window for an explicitly supplied scene:
try await Fleet.withContext(scene: windowScene) { context in ... }
```

Both forms are `@MainActor` and available on iOS and tvOS (iOS/tvOS 15 and later).

## Guarantees

- **Whole-lifetime exclusion.** The scope holds a process-local FIFO lease from before setup until after cleanup. Overlapping contexts run one at a time, in arrival order. Test execution remains serial; the lease does not make UIKit parallel-safe or permit parallel test runs.
- **Cleanup on every exit.** On return, a thrown error, a timeout or task cancellation, the context runs registered cleanups (last registered first), ends editing, dismisses presented controllers without animation (bounded at two seconds), and then restores or dismantles the window, before releasing the lease. A task cancelled while queued never holds the lease and cannot leak it.
- **Borrowed windows** get their previous root controller, key-window status and visibility restored. **Owned windows** (scene form) are made key, then hidden and detached from the scene, with the previous key window restored; owned controllers deallocate once your code drops its references.
- **Storyboard bindings.** Storyboard binds and mocks made inside the scope belong to the context and are removed (restoring any registration they overrode) before the lease is released; see [UIStoryboard](UIStoryboard.md#binding-lifetime).
- **Cleanup registration.** `context.addCleanup { }` registers context-owned resources (for example observers) to release during teardown. Using a context after its scope ends throws a `FleetFailure` of kind `.invalidSetup`.

## Nesting

`withContext` scopes do not nest. Calling `Fleet.withContext(window:)` or `withContext(scene:)` from inside an active scope, directly or from an awaited child task that inherits the scope's task-local context, throws `FleetFailure` of kind `.invalidSetup` immediately, before the lease is acquired or any UI is touched. The enclosing scope, its cleanup and the lease are unaffected, and the error is recoverable. Detached tasks do not inherit ownership: awaiting a detached `withContext` from an active scope is unsupported and would wait on the enclosing lease, which cannot be detected from the task-local value. Run independent contexts from separate tasks; they queue in FIFO order.

## Bounded waits

`waitUntil(_:timeout:pollInterval:condition:)` polls an observable condition on the main actor, yielding between checks. `waitForTransitionsToFinish()` waits until no controller in the window's presentation/navigation chain has an active `transitionCoordinator`. A non-finite `timeout` or a non-positive or non-finite `pollInterval` throws `.invalidInput` before waiting. Waits throw a `FleetFailure` of kind `.timedOut` (naming your description, the deadline and a snapshot of the window's root and topmost controllers); task cancellation propagates as the unchanged `CancellationError`, including while queued for the lease. They do not promise to flush unrelated application work. The body itself has no overall deadline: bound it with waits.

## Screen environments

`context.configure(_:)` applies a `FleetEnvironment` to the context's window and waits (bounded) until layout and the window's trait collection reflect it:

```swift
try await Fleet.withContext(window: hostWindow) { context in
    try await context.setRoot(SettingsViewController())
    try await context.configure(FleetEnvironment(
        size: CGSize(width: 320, height: 568),
        userInterfaceStyle: .dark,
        contentSizeCategory: .accessibilityExtraExtraLarge))
    XCTAssertTrue(context.screen.topmostViewController!.traitCollection.preferredContentSizeCategory.isAccessibilityCategory)
}
```

| Setting | Mechanism | Support |
| --- | --- | --- |
| `size` | `UIWindow.frame` (origin kept) | iOS/tvOS 15+ |
| `userInterfaceStyle` | `overrideUserInterfaceStyle` on the window | iOS/tvOS 15+ |
| `contentSizeCategory` | `window.traitOverrides` (Dynamic Type) | iOS/tvOS 17+; earlier runtimes throw `.invalidSetup` |
| `horizontalSizeClass`, `verticalSizeClass` | `window.traitOverrides` | iOS/tvOS 17+; earlier runtimes throw `.invalidSetup`; `.unspecified` throws `.invalidInput` |

- Unset fields are untouched; repeated calls compose. The values present before the first change are restored on every exit path (return, error, timeout, cancellation), before the lease is released, so overlapping scopes always start from the restored state. Invalid sizes throw `.invalidInput` before anything changes.
- `context.currentEnvironment` reports the window's resolved size, appearance, category and size classes for assertions. Changes made after content is hosted propagate to UIKit descendants (`traitCollection`, `traitCollectionDidChange`, layout) and through a `UIHostingController` into SwiftUI's `colorScheme`, `horizontalSizeClass` and `sizeCategory`; this is coverage of hosting, not a SwiftUI interaction API.
- Size-class overrides apply to the window's trait collection; a restored override that was absent is removed, and one that was present returns to its previous value. Wait timeouts include the resolved size, style, category and size classes.
- Localization: inject a `Bundle` or `Locale` into the object under test rather than changing the process language.
- **Not offered:** locale, language, region, right-to-left and system accessibility switches. UIKit has no public per-window control for them; changing them is process-wide and cannot be restored safely, so Fleet does not advertise them. Test localized content by injecting the bundle or locale into the object under test.
- Verified behavior is that of the current reference runtime (iOS/tvOS 26.5); iOS/tvOS 15 remains the minimum deployment target and the iOS/tvOS 17 requirement above is from the API's availability, not from running older runtimes. A window-size change does not simulate device metrics such as safe areas or scale.

## Legacy helpers and runtime hooks

`getApplicationScreen()`, `setAsAppWindowRoot(_:)` and `setInAppWindowRootNavigation(_:)` look up the key window without coordination. Use them serially and do not mix them with a running context. Runtime hooks (swizzles) remain installed process-wide; contexts do not toggle them.
