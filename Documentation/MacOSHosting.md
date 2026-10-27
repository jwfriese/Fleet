# Scoped macOS SwiftUI hosting

`FleetMacOS` is a separate, test-only SwiftPM product (macOS 13+). It does not depend on UIKit, the `Fleet` product or the Objective-C runtime hooks, so linking it installs no swizzles. Swift Testing and XCTest can both use it.

```swift
import FleetMacOS

@MainActor @Test func unlockShowsAccount() async throws {
    let model = SessionModel(auth: FakeAuthenticator())
    try await FleetMacOS.withHostedView(RootScreen(model: model)) { host in
        try await host.waitUntilReady()
        model.unlock()
        try await host.waitForUpdate("account form") { model.isUnlocked }
        model.revoke()
        try await host.waitForUpdate("private content cleared") { model.draft.isEmpty }
    }
}
```

`withHostedView(_:window:_:)` mounts an `NSHostingController` in a borrowed `NSWindow` (its content controller, frame and visibility are restored) or, with no window, in one the scope creates and closes.

- **Serialization:** a process-local FIFO lease is held from before setup until after cleanup, so overlapping async tests run one at a time. Nesting throws `FleetMacOSFailure(.invalidSetup)`.
- **Bounded waits:** `waitUntil`, `waitUntilMounted`, `waitUntilReady`, `waitForAppearance` and `waitForUpdate` fail with `.timedOut` (including a window snapshot) at the deadline, `.invalidInput` for a non-finite timeout, and propagate cancellation unchanged.
- **Cleanup:** on return, error and cancellation, registered `addCleanup` closures run (last first), the root is removed, Fleet waits (bounded) for SwiftUI's `onDisappear`, and the window is restored or closed before the lease is released. A host used after its scope throws.

## Limits

Fleet observes the mounted hierarchy and the application state you name. It does not send physical input, prove hit testing or accessibility, drive AppKit controls, or exercise OS authentication, Keychain or biometrics: inject a fake service, and cover real OS authentication with a separate signed integration check. Interactions with controls require another inspection tool (for example ViewInspector) or calling the same closure the control runs. The iOS/tvOS `Fleet` product and its validation are unchanged. Plain `swift test` on the full manifest also tries to build the UIKit `Fleet` target, so it is not the validation route.

## Support and validation

- **Minimum deployment:** macOS 13, set in `Package.swift`. It is the lowest version the manifest declares; it is not a statement that macOS 13 through 25 were run.
- **Actually tested:** one host and toolchain at a time, as recorded in the receipt: the Xcode 26.6 / Swift 6.3.3 baseline on the macOS version of the machine that ran the check (the `macos-26` GitHub-hosted runner in CI). No other macOS version has been run.
- **Not provided:** AppKit control interaction, gesture breadth, accessibility or hit-testing proof, and any UIKit `Fleet` feature. `FleetMacOS` is hosting only; it does not mirror `Fleet.withContext`, `FleetEnvironment` or the `UI*` pages.

## Reproducing the external-consumer check

```
script/check-distribution macos            # clean committed checkout; certifies the exact revision
script/check-distribution macos --allow-dirty   # development snapshot; cannot certify a revision
script/check-distribution                  # iOS, tvOS and macOS
```

The macOS run generates a separate Xcode project from `Integration/MacOSConsumer/` whose only package dependency is the `FleetMacOS` product, pinned to the exact Git revision (a development snapshot with `--allow-dirty`). It imports only public API (no `@testable`) and does not copy the implementation or reuse the package's `FleetMacOSTests` target. It does not build the UIKit `Fleet` product. The consumer covers, with XCTest and Swift Testing: owned windows; borrowed windows with a content controller, a direct content view with subviews, content size limits, frame and visibility; thrown errors and last-first cleanups; bounded timeouts and invalid input; nesting; cancellation followed by a successor scope that starts clean; and use of a host after its scope.

The command fails unless the lockfile pins exactly the requested revision, the xcodebuild log reports a nonempty successful XCTest total and a nonempty successful Swift Testing total, and the built test bundle's load commands and undefined symbols contain no UIKit, `Fleet` framework or `FleetRuntime` reference and the build produced no `FleetRuntime` artifact. Under `build/distribution-*/` it retains `macos/xcodebuild.log`, `macos/TestResults.xcresult`, `macos/Package.resolved`, `macos/link-graph.json` and `validation.json` (`package_revision`, `macos_tests` with `xctest` and `swift_testing` counts, `macos_linked_libraries`, `products`). This receipt is adoption and support evidence for that revision, not a release or version selection.
