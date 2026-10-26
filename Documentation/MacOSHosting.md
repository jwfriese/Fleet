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

Fleet observes the mounted hierarchy and the application state you name. It does not send physical input, prove hit testing or accessibility, drive AppKit controls, or exercise OS authentication, Keychain or biometrics: inject a fake service, and cover real OS authentication with a separate signed integration check. Interactions with controls require another inspection tool (for example ViewInspector) or calling the same closure the control runs. The iOS/tvOS `Fleet` product and its validation are unchanged. This repo's macOS checks run the `FleetMacOSTests` target in a package-only directory (`xcodebuild test -scheme <package scheme> -destination 'platform=macOS'`); plain `swift test` on the full manifest also tries to build the UIKit `Fleet` target.
