# Migrating to the next major Fleet release

This guide inventories what changes for a test suite moving from Fleet 4.x to the modern checkout, and points at executable examples. No next-major version has been selected or published; until then, depend on a local checkout or an exact revision. Nothing here selects a version or authorizes publication.

Code you can copy is compiled and run, not merely documented: the [quick start](QuickStart.md) holds a Swift Testing starter and a plain XCTest starter. Both are verbatim regions of the independent package-consumer fixtures (`Integration/PackageConsumer/`), which `script/check-distribution` builds against the exact committed revision on iOS and tvOS, and a tooling test fails if the pages drift from the compiled source.

## Breaking changes

| Area | 4.x | Modern checkout | Where to read more |
| --- | --- | --- | --- |
| Toolchain | Historical Xcode releases, Swift 5 | Xcode 26.6 / Swift 6.3.3 reference; Swift 6 language mode for library and consumers; SwiftPM tools version 6.3 | [Compatibility](Compatibility.md) |
| Minimum OS | Older deployment targets | iOS 15 / tvOS 15 for framework, test and host targets | [Compatibility](Compatibility.md) |
| Distribution | CocoaPods, Carthage, direct integration | SwiftPM only (dynamic `Fleet` product, linked to the test target). Older routes stay on 4.x tags | [SwiftPM](Installation/SwiftPM.md) |
| Concurrency | Unannotated, callable from anywhere | UI helpers, `FLTScreen`, storyboard bindings are `@MainActor`. Mark test classes `@MainActor`, use `async` `setUp`/`tearDown`, and hop to the main actor from other tasks | [Compatibility](Compatibility.md) |
| Hosting | `Fleet.setAsAppWindowRoot`, `Fleet.getApplicationScreen` use the global key window | `Fleet.withContext(window:)` / `withContext(scene:)` give each test an explicit, serialized, cleaned-up host. The legacy helpers remain but must not be mixed with a context. Contexts do not nest | [Hosting](Hosting.md) |
| Cleanup and isolation | Manual teardown; storyboard binds and mocks persist until unbound | Context cleanup restores roots, dismisses presentations, removes context-owned storyboard bindings, and runs `context.addCleanup` callbacks. Environment (size, appearance, content size) is configured through the context and restored | [Hosting](Hosting.md), [UIStoryboard](UIStoryboard.md) |
| Errors | Helpers raise Objective-C exceptions, handled with `Fleet.swallowAnyErrors` | Each `...OrThrow` helper throws `FleetFailure` (`.invalidSetup`, `.invalidInput`, `.unavailableInteraction`, `.timedOut`). Classic helpers still raise `FleetError`. Cancellation propagates as `CancellationError` | [FAQ](FAQ.md) |
| Table row actions | `selectCellAction` and `UITableViewRowAction` handler interception | Removed with no compatibility module. Use `performContextualAction` (iOS only) | [UITableView](UITableView.md), [RuntimeHooks](RuntimeHooks.md) |
| Alerts | Title matching took the first match | `tapAlertAction(withTitle:)` rejects ambiguous titles, disabled actions and unpresented alerts | [UIAlertController](UIAlertController.md) |
| Navigation | Some pops returned `nil` for removed controllers | Pops return the removed controllers in stack order, `nil` only for root-only or empty stacks | [UINavigationController](UINavigationController.md) |
| Bar button items | Target/action only | Primary action and target/action each run once; without a target the responder chain is used and failure is typed | [UIBarButtonItem](UIBarButtonItem.md) |

## Suggested order

1. Raise deployment targets and switch the dependency to SwiftPM, following the storyboard-metadata setup in [SwiftPM](Installation/SwiftPM.md).
2. Compile in Swift 6; annotate test classes `@MainActor` and make fixtures `async`.
3. Move one test to `Fleet.withContext` using a starter, then migrate the rest. Replace `swallowAnyErrors { helper() }` with `try helper...OrThrow()`.
4. Replace `selectCellAction` use with `performContextualAction`.
5. Run your suite serially; do not enable parallel execution of UIKit tests.

## Supported and unsupported

Supported: the APIs documented in this directory, on iOS and tvOS 15 and later where the page does not say otherwise, through SwiftPM, in hosted unit tests.

Not supported or not promised: CocoaPods, Carthage or direct integration for the next major; the historical `Examples/FleetExamples` project (not revived, not built by CI); plain macOS `swift test`; parallel UIKit test execution; physical hit-testing, accessibility or real keyboard presentation (programmatic helpers do not prove them); isolation from initialization side effects of runtime-mocked controllers.

## Deployment targets versus verified runtimes

The deployment target (15) is what the code declares it can run on. The verified runtime is where the suites actually executed: currently the iOS and tvOS 26.5 simulators with Xcode 26.6. Passing there does not establish behavior on iOS/tvOS 15 through 25. Individual features can also be availability-gated within the supported range (for example `FleetEnvironment(contentSizeCategory:)` requires iOS/tvOS 17; contextual swipe actions and text-field clear/flip helpers are iOS only). A statement of verification must name the runtime it was observed on.

## Candidate scope and readiness

Which completed work belongs in a candidate (for example #55 and any selected follow-ups) is decided per candidate by the maintainer. The evidence for an exact revision is recorded as described in [Readiness reports](ReadinessReport.md).
