# Scoped SwiftUI hosting and lifecycle observation

Fleet owns the host and its lifetime; your application owns services, clocks, streams and domain rules. Inject fakes into the view yourself (`.environmentObject(...)`). ViewInspector stays optional: see [ViewInspector](ViewInspector.md) for how to inspect the same mounted screen.

```swift
try await Fleet.withHostedView(Screen().environmentObject(fake), window: window) { host in
    // host.isReady, host.lifecycle, host.hostingController
}
```

`withHostedView(_:window:_:)` borrows a window; `withHostedView(_:scene:_:)` creates and removes one for an explicit scene. Normal return, a thrown error, a failed wait and task cancellation all remove the screen, give observed tasks a bounded chance to observe cancellation, and restore the window. A handle used after its scope throws `FleetFailure(.invalidSetup)`.

## Distinct observations

| Observation | API | Established by |
| --- | --- | --- |
| Mounted | `waitUntilMounted` | hosting view is in the context window |
| Ready | `waitUntilReady` | mounted with positive size |
| Appeared | `waitForAppearance`, `lifecycle` | SwiftUI delivered `onAppear` |
| Updated | `waitForUpdate(_:condition:)` | your condition over live application state |
| Removed / disappeared | `remove()` | root removed, then SwiftUI delivered `onDisappear` |
| Task started / cancelled | `waitForTaskStart`, `waitForTaskCancellation` | `fleetObservedTask` reports the real SwiftUI task start and the cooperative return after cancellation; `fleetObservedTask(_:id:)` covers `task(id:)` replacement |

Every wait is bounded and fails with a `FleetFailure(.timedOut)` carrying the operation, target, state and resolved window environment. Callbacks are never invoked manually as proof. Fleet cannot see or cancel arbitrary `Task`s your code creates, and does not flush all work; cancellation is observed only if the task body returns on cancellation.

## Lower-level route

`context.mount(view)` installs the root and returns immediately: no layout pass, no waits. Call `layoutIfNeeded()` and the wait methods in the order you want to exercise, for example an initial zero-size sequence. `context.host(view)` is the convenience equivalent. Neither alters `FleetEnvironment`, which still rejects non-positive sizes.

## Support matrix

| Feature | iOS | tvOS |
| --- | --- | --- |
| Scoped host, lifecycle events, observed tasks, sheet content | Covered by native and consumer tests | Native tests compile and run; not separately advertised |
| Minimum OS | iOS/tvOS 15 (unchanged) | |

The starters are compiled in `Integration/PackageConsumer/SwiftUIHostingConsumerTests.swift` (XCTest and Swift Testing) and run by `script/check-distribution`.
