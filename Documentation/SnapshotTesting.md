# Named hosted environments and optional snapshots

Fleet owns the hosted screen, its lifecycle and the restoration of window-scoped settings. An established library, [SnapshotTesting](https://github.com/pointfreeco/swift-snapshot-testing), may compare images. It stays out of Fleet's package, framework and native targets and is compiled only into an external consumer's test target. The direct oracle below needs no snapshot library.

Sources: `Integration/PackageConsumer/EnvironmentCasesConsumerTests.swift` (driver and direct oracle, always compiled) and `Integration/PackageConsumer/SnapshotTesting/SnapshotEnvironmentTests.swift` (adapter, compiled by default by `script/check-distribution`, including hosted CI, unless `--without-snapshottesting` is passed). Reproduce with `script/check-distribution --allow-dirty [ios|tvos]`; the mismatch images are attachments in the result bundles.

## The named-case driver (a recipe, not API)

`EnvironmentCases.run(_:window:_:)` runs each `EnvironmentCase` in its **own sequential** `Fleet.withHostedView` scope, applies `FleetEnvironment` with `context.configure`, waits for an explicit readiness state (`host.isReady` and the hosting view adopting the requested size), then calls your body with the mounted `FleetHostedView`, a `CaseReport` and a probe of the mounted screen.

- Scopes are never nested. Each case ends (removal, `onDisappear`, window restoration) before the next begins, on return, thrown error and cancellation. Tests assert the window frame, override style, root and Dynamic Type are back at baseline after an error and after cancellation.
- `CaseReport.label` is `[case <name> | resolved <FleetEnvironment> | features <availability and injected inputs>]`. The tests put it in every assertion message, and the snapshot adapter prefixes it to the library's failure and names reference and artifact files after the case. A `FleetFailure` raised inside a case is rethrown as `CaseFailure` with the case name and the unchanged underlying failure.
- Per-feature availability: `contentSizeCategory` and size classes need iOS/tvOS 17 trait overrides (the report states `traitOverrides=`); the tests skip on older runtimes. The large-text case is iOS-only: on tvOS the override did not change the hosted content (identical fitted height and rendering), so it is not claimed there. Window size does not establish safe areas, keyboard geometry or display scale.

## Injected localization and direction

The cases inject `Locale` and `LayoutDirection` into the SwiftUI tree (`.environment(\.locale, …)`, `.environment(\.layoutDirection, …)`) and pass localized strings explicitly. Nothing changes process-wide language, region or accessibility settings. The UIKit side is **not** changed: the hosting view's `effectiveUserInterfaceLayoutDirection` stays that of the window, and UIKit text, `semanticContentAttribute` and UIKit-only screens would need their own explicit dependencies (a localized bundle or injected strings, and an explicit `semanticContentAttribute`). The examples do not claim UIKit right-to-left behavior.

## Capturing the existing mounted screen

SnapshotTesting's `UIView` strategy moves the view into a window it creates, and its SwiftUI strategy builds a new `UIHostingController`; either would snapshot a second instance and could displace Fleet's host. The adapter (`captureMounted`) instead draws the **mounted** hosting view in place at scale 1, after checking it is the ready root of Fleet's window, and passes only the `UIImage` to the library's `Snapshotting<UIImage, UIImage>.image` for storage, comparison and diff. A view that is not mounted is refused with an error; it is never replaced by another snapshot.

## Mismatch evidence and recording policy

A deliberate mismatch (light reference, dark actual) is reported by SnapshotTesting with the reference, failure and difference images as XCTest attachments in the result bundle (named `reference`, `failure`, `difference`) and the failing image written under `SNAPSHOT_ARTIFACTS`. `script/check-distribution` sets that to `snapshot-artifacts/` beside each platform's results.

`SnapshotRecordPolicy` is explicit: `.verify` (default; compares, a missing reference fails) or `.record` (`FLEET_SNAPSHOT_RECORD=1`, passed as `TEST_RUNNER_FLEET_SNAPSHOT_RECORD=1`; rewrites references and reports a failure so it cannot pass CI). The tests record into a per-test temporary directory and verify against it in the same process, so they commit no binary images and are reproducible by construction. Committed references would also need the Xcode, simulator runtime and device pinned, because rendering differs across them.

## Pinned configuration

| Item | Value |
| --- | --- |
| SnapshotTesting | release **1.12.0**, revision `26ed3a2b4a2df47917ca9b790a57f91285b923fb` (no transitive packages, so the consumer lockfile gains exactly one pin) |
| Toolchain / runtimes | Xcode 26.6, Swift 6.3.3; iOS/tvOS 26.5 simulators |
| Scale | references are drawn at scale 1 |

Later SnapshotTesting releases add swift-syntax and other packages; moving the pin is a deliberate change to this table and the checker.
