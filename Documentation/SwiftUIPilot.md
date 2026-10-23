# SwiftUI adoption pilot: setup, support and certification

This page describes the supported SwiftUI path as a distributed package, how its pilot evidence is produced for one exact revision, and what that evidence does and does not cover. The supported APIs are in [Scoped SwiftUI hosting](SwiftUIHosting.md); optional inspection is in [ViewInspector](ViewInspector.md).

## Setup

Add Fleet as a SwiftPM dependency of a hosted unit-test target only (never of the app target), pinned to a revision. Use Swift 6 language mode and iOS/tvOS 15 or newer ([Compatibility](Compatibility.md)). Services, clocks, streams and domain rules stay in your application: inject fakes into the view and register their shutdown with `host.context.addCleanup`. Policy: the default legacy process policy keeps Fleet's nonanimated, eager UIKit behavior; launching the test process with `FLEET_HOSTING_POLICY=preserve-timing` keeps UIKit's own timing, so tests must wait for the state they assert ([RuntimeHooks](RuntimeHooks.md)). The policy is fixed at process start.

## Per-platform support matrix

| Capability | iOS | tvOS |
| --- | --- | --- |
| Scoped host, injected fake, asynchronous state change, observed tasks, teardown on return/throw/cancellation | Supported; consumer-verified (XCTest and Swift Testing) | Supported; consumer-verified |
| Optimistic-deletion starter (`fleetElement`, `perform`, pending-response cleanup) | Supported; consumer-verified | Supported; consumer-verified |
| Sheet and `NavigationStack` content observation | Supported (`NavigationStack` requires iOS 16; skipped below) | Not claimed |
| `UIViewControllerRepresentable` crop fixture (zero to non-zero layout) | Supported; consumer-verified | Not applicable (uses `UIToolbar`) |
| Optional ViewInspector integration | Consumer-verified (`--with-viewinspector`) | Consumer-verified (`--with-viewinspector`) |
| `preserve-timing` and legacy policies | Separate test-host processes, with a no-Fleet baseline for the timing claim | Same |

## What the consumers cover

The independent generated project (`script/consumer_project.py`) pins Fleet by Git revision, links Fleet only to the test target, and uses public APIs only. In `Integration/PackageConsumer/`:

- `SwiftUIHostingConsumerTests.swift`: an injected fake dependency, asynchronous state change, sheet content, and the optimistic-deletion screen through XCTest and Swift Testing. `OptimisticDeletionMutationTests` shows the corrected flow passing, a model that defers removal until the response failing only the optimistic-stage assertion (`DeletionAssertion.notOptimistic`), and a model that skips restoring the row failing only the rollback assertion (`.notRestored`). `FailureIsolationTests` shows that a throwing or cancelled scope releases the pending response continuation, releases the model and service, keeps the window root, and leaves a successor screen clean.
- `CropQueueConsumerTests.swift`: the `UIViewControllerRepresentable` crop fixture; each crop mutation fails its own named assertion ([CropQueueFixture](CropQueueFixture.md)).
- `PresentedContentConsumerTests.swift`, `SwiftTestingConsumerTests.swift`, `PackageConsumerTests.swift`: sheet and navigation content, typed failures, bounded waits and cleanup.
- `BaselineTraceTests.swift` and `HostingTraceScenario.swift`: the no-Fleet comparison (a bundle that links no Fleet product) against the legacy and preserve-timing traces.

## Repetition plan (recorded before execution)

Execution is serial; failures are diagnosed from their result bundles, never retried away. Every attempt's counts, failures, logs and result bundles are kept under `build/`.

| ID | Case | Platforms | Mode |
| --- | --- | --- | --- |
| P1 | `script/test all` on the committed revision | iOS, tvOS | Fresh process |
| P2 | `python3 -m unittest discover -s script/tests -v`, shell syntax checks, `git diff --check` | host | n/a |
| P3 | `script/check-distribution` (legacy and preserve-timing consumer processes, plus baseline), clean committed tree | iOS, tvOS | Fresh process per policy |
| P4 | Consumer re-run on the same revision | iOS, tvOS | Fresh process (repeat) |
| P5 | Consumer failure/cancellation tests followed by neighboring hosted tests in one process | iOS, tvOS | Process reuse (inside P3) |

P5 covers controller, binding, observer, continuation, coordinator and task release (crop teardown tests, `FailureIsolationTests`, optimistic-deletion cleanup). A case that is not run is reported as not run.

## Receipt

The receipt is produced after the commit, for one full hash, by the steps in [Readiness reports](ReadinessReport.md), and kept with the retained evidence (`build/` and CI artifacts), not committed. It must list toolchain, runtimes, policy and dependency revisions, per-suite counts split between XCTest and Swift Testing, durations, and what was not validated. It is documentation or PR evidence, not a GitHub release, and selects no version.

## What this evidence is not

The fixtures are generic recipe-shaped and crop-shaped examples. They are **representative-fixture evidence**; they are not validation of any downstream application, whose code was not available. Real downstream validation is a separate step. Hosted CI results are separate from local runs. Physical hit testing, accessibility, pixels, snapshots, gestures, clocks and streams are outside this pilot.
