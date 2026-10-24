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

See the [adoption pilot](SwiftUIPilot.md) for setup, certification and limits. The starters are compiled in `Integration/PackageConsumer/SwiftUIHostingConsumerTests.swift` (XCTest and Swift Testing) and run by `script/check-distribution`.

## Operating and observing mounted elements (optimistic updates)

Mark the screen's rows with `fleetElement(_:text:actions:)`, using a stable model identity, and give each `FleetElementAction` the same closure the row's control runs:

```swift
let delete = { model.delete(ingredient) }
HStack { Text(ingredient.name); Button("Delete", action: delete) }
    .fleetElement("ingredient.\(ingredient.id)", text: ingredient.name,
                  actions: [FleetElementAction("Delete", isEnabled: !model.deleting.contains(ingredient.id), perform: delete)])
```

| API | Meaning |
| --- | --- |
| `host.perform("Delete", onElement:)` | invokes that one row's action; never "the first Delete" |
| `host.mountedElementIDs`, `host.element(_:)` | identities in visual order; text, window-coordinate frame and action state of one element |
| `host.waitForElement(_:)`, `host.waitForElementRemoval(_:)` | bounded waits on the laid-out SwiftUI hierarchy |

The rendered observation is the mounted SwiftUI hierarchy as reported by layout (identity, text, geometry), not view-model arrays and not ViewInspector declaration inspection. It does not prove physical hit testing, accessibility labels or pixels; add a snapshot or accessibility check separately if you need those. A request fails with `FleetFailure`: `.invalidInput` for a missing element, an ambiguous identity (several mounted elements share it) or an action the element does not offer; `.unavailableInteraction` for a disabled action. Each names the element identity and action, and the caller's file and line.

The maintained example in `SwiftUIHostingConsumerTests.swift` (`IngredientsScreen` with `FakeIngredientService`) holds the request at explicit checkpoints, asserts the row is already gone while the response is pending, then releases failure (row restored at its original position with a visible error) or success. The fake, its continuations and the model's tasks are application-owned: register `model.shutdown()` with `host.context.addCleanup` so cancellation or an early failure releases pending continuations and ignores late results. Fleet does not provide a networking or service abstraction. This fixture does not certify behavior in any downstream application.

## Injected clocks and household event streams across an optimistic operation

`Integration/PackageConsumer/HouseholdPlanConsumerTests.swift` (public APIs only; XCTest and Swift Testing starters between `household-plan-*` markers) extends the optimistic example with application-owned inputs:

- **Clock.** `PlanClock` carries the date, `Calendar` and `TimeZone` into the screen; the test advances it across a local midnight / week boundary and asserts the rendered "Today" and "Week of" elements. The same instant under another injected zone renders a different day. The process time zone and `NSTimeZone.default` are never changed (the test asserts that).
- **Event stream.** `HouseholdEventStream` is a controllable `AsyncStream` source the test sends to; the screen subscribes inside `fleetObservedTask`. Fleet adds no networking, scheduler or clock framework.
- **Fake service.** Saves stay pending at explicit checkpoints until the test fails or releases them.
- **Conflict policy (fixture choice, not a recommendation).** `keepNewerHouseholdChange` restores only the entry the failed save changed, and only if no remote event touched it meanwhile; otherwise the newer household change stays and a notice says so. `restoreSnapshot` is the simplistic whole-snapshot rollback, included as a mutant: the screen shows it losing a later change.
- **Departure.** `host.remove()` then `waitForTaskCancellation` observes the cooperative cancellation of the observed subscription task only; `shutdown()` releases pending fake continuations. Late events then reach no subscriber (`send` returns 0), late failures find nothing pending, and a successor screen's state is untouched. Fleet does not cancel arbitrary application `Task`s; the model cancels its own.

Waits are bounded conditions on the rendered elements or application checkpoints (no sleeps, no run-loop flushing). The fixture is recipe-shaped and does not certify any downstream application.
