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
- **Cleanup registration.** `context.addCleanup { }` registers context-owned resources (for example storyboard bindings or observers) to release during teardown. Using a context after its scope ends throws a `FleetFailure` of kind `.invalidSetup`.

## Bounded waits

`waitUntil(_:timeout:pollInterval:condition:)` polls an observable condition on the main actor, yielding between checks. `waitForTransitionsToFinish()` waits until no controller in the window's presentation/navigation chain has an active `transitionCoordinator`. A non-finite `timeout` or a non-positive or non-finite `pollInterval` throws `.invalidInput` before waiting. Waits throw a `FleetFailure` of kind `.timedOut` (naming your description, the deadline and a snapshot of the window's root and topmost controllers); task cancellation propagates as the unchanged `CancellationError`, including while queued for the lease. They do not promise to flush unrelated application work. The body itself has no overall deadline: bound it with waits.

## Legacy helpers and runtime hooks

`getApplicationScreen()`, `setAsAppWindowRoot(_:)` and `setInAppWindowRootNavigation(_:)` look up the key window without coordination. Use them serially and do not mix them with a running context. Runtime hooks (swizzles) remain installed process-wide; contexts do not toggle them.
