# Scoped SwiftUI hosting and lifecycle observation

Fleet owns the host and its lifetime; your application owns services, clocks, streams and domain rules. Inject fakes into the view yourself (`.environmentObject(...)`). ViewInspector stays optional: see [ViewInspector](ViewInspector.md) for how to inspect the same mounted screen.

```swift
try await Fleet.withHostedView(Screen().environmentObject(fake), window: window) { host in
    // host.isReady, host.lifecycle, host.hostingController
}
```

`withHostedView(_:window:_:)` borrows a window; `withHostedView(_:scene:_:)` creates and removes one for an explicit scene. Normal return, a thrown error, a failed wait and task cancellation all remove the screen, wait (bounded, independently) for SwiftUI's `onDisappear` and for observed tasks to observe cancellation, and restore the window. The same teardown runs for handles from `context.host` and `context.mount`, before the context releases its lease. A handle used after its scope throws `FleetFailure(.invalidSetup)`.

## Distinct observations

| Observation | API | Established by |
| --- | --- | --- |
| Mounted | `waitUntilMounted` | hosting view is in the context window |
| Ready | `waitUntilReady` | mounted with positive size |
| Appeared | `waitForAppearance`, `lifecycle` | SwiftUI delivered `onAppear` |
| Updated | `waitForUpdate(_:condition:)` | your condition over live application state |
| Removed / disappeared | `remove()` | root removed, then SwiftUI delivered `onDisappear` |
| Presented / content / dismissed | `waitForContentPresented`, `waitForContent`, `waitForContentDismissed` | see below |
| Task started / cancelled | `waitForTaskStart`, `waitForTaskCancellation` | `fleetObservedTask` reports the real SwiftUI task start and the cooperative return after cancellation; `fleetObservedTask(_:id:)` covers `task(id:)` replacement |

Every wait is bounded and fails with a `FleetFailure(.timedOut)` carrying the operation, target, state, resolved window environment and the caller's file and line (`FleetFailure.source`). Callbacks are never invoked manually as proof. Fleet cannot see or cancel arbitrary `Task`s your code creates, and does not flush all work; cancellation is observed only if the task body returns on cancellation.

## Observing NavigationStack destinations and sheets

A model's path or presentation flag does not prove what is on screen. Fleet therefore observes presentation through content that reports itself: attach `.fleetObservedContent("recipe-detail", ["recipe": name, "image": image])` inside the destination or sheet, using the same values it renders. This is the supported seam; Fleet never reads private SwiftUI controller classes and does not assume a path maps to `UINavigationController`. Outside a Fleet host the modifier does nothing.

| Observation | API | Established by |
| --- | --- | --- |
| Presented | `waitForContentPresented(_:count:)` | content with that identity is mounted and in the window (`count: 2` for a repeated presentation) |
| Content ready | `waitForContent(_:values:)` | the displayed content reports every expected value; stale values time out and the failure names what was displayed |
| Dismissed | `waitForContentDismissed(_:)`, `waitForModalDismissal()` | the content is gone from the window and unregistered; the latter also requires no UIKit modal (sheets only) |

`currentContent(_:)`, `observedContent` and `presentationCount(of:)` read the same state synchronously. Underlying content is asserted the same way: while a pushed destination covers a screen it is not displayed, and it is displayed again after the pop. Each wait is bounded, throws a typed `FleetFailure(.timedOut)` with the caller's location, and propagates task cancellation. Scope end requires all observed content to leave the window. Application-owned asynchronous work (the examples gate it on a continuation) stays yours to release; Fleet does not flush it. These are preserve-timing-safe condition waits and need no legacy hooks.

`NavigationStack` requires iOS 16; the examples in `Integration/PackageConsumer/PresentedContentConsumerTests.swift` are availability-gated and skip below it, leaving the iOS/tvOS 15 minimum unchanged. Sheet and navigation examples run on iOS only; tvOS behavior is not claimed.

## Lower-level route

`context.mount(view)` installs the root and returns immediately: no layout pass, no waits. Call `layoutIfNeeded()` and the wait methods in the order you want to exercise, for example an initial zero-size sequence. `context.host(view)` is the convenience equivalent. Neither alters `FleetEnvironment`, which still rejects non-positive sizes.

## Support matrix

| Feature | iOS | tvOS |
| --- | --- | --- |
| Scoped host, lifecycle events, observed tasks, sheet content | Covered by native and consumer tests | Native tests compile and run; not separately advertised |
| Minimum OS | iOS/tvOS 15 (unchanged) | |

The starters are compiled in `Integration/PackageConsumer/SwiftUIHostingConsumerTests.swift` (XCTest and Swift Testing) and run by `script/check-distribution`.
