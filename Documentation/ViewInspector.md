# ViewInspector compatibility (feasibility proof)

Fleet offers no SwiftUI inspection API. This page records an executable proof of how the optional [ViewInspector](https://github.com/nalexn/ViewInspector) library can observe the SwiftUI screen a Fleet context owns. ViewInspector stays out of Fleet's package, framework and native targets; the proof compiles it only into an external consumer's test target.

## Supported matrix (what was run)

| Item | Value |
| --- | --- |
| ViewInspector | release **0.10.5**, revision `2dacb6e514be19379c605a5a11564d0f3fea89d9` (the `0.10.6` default branch is not used) |
| Toolchain | Xcode 26.6, Swift 6.3.3, consumer in Swift 6 language mode |
| Runtimes | iOS and tvOS simulator 26.5 (iOS/tvOS 15 remains Fleet's minimum; older runtimes were not run) |
| Test frameworks | XCTest and Swift Testing, both in the same consumer test bundle |
| Result | iOS 30 XCTest + 16 Swift Testing tests, tvOS 29 + 16, all passing (the proof adds 1 XCTest and 6 Swift Testing tests) |

Reproduce with `script/check-distribution --allow-dirty --with-viewinspector [ios|tvos]` (source: `Integration/PackageConsumer/ViewInspector/ViewInspectorProofTests.swift`). The flag adds a second Git-pinned package to the consumer project; default runs are unchanged.

## The seam: do not use `ViewHosting`

ViewInspector's `ViewHosting.host(view:)` creates its own window. The proof shows it adds a window to the scene that Fleet does not own and that `ViewHosting.expel()` does not detach it. Calling both hosting paths therefore inspects a different tree than the Fleet-owned one.

Instead:

1. **Application seam** (no ViewInspector import; Combine only): the screen takes an `InspectionSeam` and subscribes with `.onReceive(seam.notice) { seam.visit(self) }`. The seam is a main-actor, single-slot rendezvous. It uses no continuation and no `@unchecked Sendable`; each request is cleared when `run` returns, whether or not a mounted instance answered.
2. **Fleet owns the host**: `Fleet.withContext(window:)` + `context.setRoot(UIHostingController(rootView: ...))`.
3. **Test-side inspection**: `context.waitUntil` repeatedly offers the request to the mounted screen; the screen answers synchronously with its live `self`, and the test runs `self.inspect()`.

The proof asserts that the hosting controller's view is in the Fleet window, the scene's window set and key window are unchanged, a ViewInspector `button.tap()` runs the real action (`@State` and the injected `@EnvironmentObject` model both change), the re-rendered state is observed through the same seam after a bounded wait, `onAppear` ran exactly once (no second mount), and an unmounted value copy never answers the seam and only acts on its own injected model.

## Waits, cancellation and errors

- No answer within the timeout: `FleetFailure` of kind `.timedOut`.
- Task cancellation: the unchanged `CancellationError`.
- An error thrown by the inspection body (for example ViewInspector's `InspectionError`) propagates unchanged.
- In all three the seam's request slot is empty afterwards (asserted in XCTest and Swift Testing). A screen that is retained but no longer hosted can still answer; use a fresh seam per hosted screen.

## Kinds of evidence (not interchangeable)

| Evidence | Established by | Not established |
| --- | --- | --- |
| Declaration | `inspect()` on a value: structure of `body` | that anything is mounted |
| Current mounted state | the seam answering from the hosted instance, after a bounded wait | pixels, layout |
| Rendered hierarchy/layout | UIKit view, frame and snapshot checks on the Fleet-owned hosting view | ViewInspector does not read these |
| Physical interaction | not provided: `tap()` invokes the action closure directly, without hit testing or accessibility | touch delivery, gestures |

Do not substitute body reflection for rendered evidence.

## Row-scoped queries and the tested control matrix

`Integration/PackageConsumer/ViewInspector/ScopedInspectionTests.swift` adds a test-side adapter (`ScopedInspector`); it lives in the consumer test target, so Fleet core gains no SwiftUI introspection engine. It builds on the same mounted-instance seam and does not replace the minimal `fleetElement` row actions, which remain independent of it.

- **Scopes.** `container(_:)` descends into the single view with an `accessibilityIdentifier` (use stable model identifiers, not positions). Controls are then matched by label/title inside that scope only, so "Remove" in different ingredient rows is unambiguous.
- **Exact-one.** Every singular lookup requires exactly one match. `ScopedQueryFailure` keeps `absent`, `ambiguous` (with count), `disabled` and `unsupported` distinct, each naming the target and scope; none takes a first match.
- **Evidence level.** ViewInspector reports *declaration content of the mounted instance*. It does not report layout, offscreen/lazy realization or visibility: a declared lazy or offscreen child is found (tested with a 44-point `ScrollView` containing a `LazyVStack`; finding it is not evidence of realization or visibility, which `ScopedInspector.unsupported("visibility")` reports as unsupported), a conditional branch that is not currently declared is absent. Use `fleetElement` frames, the hosting view or a snapshot for rendered claims. Handles are not immutable snapshots: a retained text-field handle's `input()` reads the live binding and returns the current value after state changes (tested), and a handle is only meaningful inside the inspection that produced it. Re-query inside a fresh inspection after state changes.

| Control | Operation | What it does (never a physical touch) |
| --- | --- | --- |
| Button | `tap(_:)` | invokes the button's action closure |
| TextField | `setText(_:to:)` | writes the text binding |
| TextField | `submit(_:)` | invokes the `onSubmit` closure |
| Toggle | `set(toggle:to:)` | writes the isOn binding (taps only when the value differs) |
| Picker | `select(_:in:)` | writes the selection binding |

Disabled controls fail with `.disabled` before acting. Anything else (swipe actions, context menus, gestures, rendered text or visibility) returns `ScopedQueryFailure.unsupported` with a recommendation: an explicit `fleetElement` action, a frame/snapshot observation, or an XCUITest. Nothing is simulated through private hooks.

Compiled through the public consumer with ViewInspector 0.10.5 on iOS/tvOS 26.5 (Swift Testing, 5 tests; the table above is limited to what those tests exercise).

## Limits

The proof covers one `@State`/`@EnvironmentObject` screen. It does not cover popovers, sheets, navigation destinations, `@StateObject` inside children, or views not at the hosting root. If a use case needs them, add a bounded adapter rather than widening this claim. Fleet does not ship a SwiftUI query API on the strength of this proof.
