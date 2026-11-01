# Mounted macOS Button, TextField and SecureField interaction

Platform: macOS 13+. This is a validated, optional inspection adapter, not a Fleet API. `FleetMacOS` hosts the screen ([MacOSHosting.md](MacOSHosting.md)); the adapter drives the mounted controls through [ViewInspector](https://github.com/nalexn/ViewInspector), which is compiled only into a test target. Neither `FleetMacOS`, `Package.swift` nor an application target depends on ViewInspector, and the application gains no runtime hook beyond the Combine seam below.

A public AppKit route does not exist for Button: a SwiftUI `Button` is not an `NSButton`, and the hosting view exposes no accessibility press target for it. TextField and SecureField do render as AppKit text fields, but the adapter writes their SwiftUI binding directly so both control kinds share one exact-one query model.

## What it does and does not do

| Operation | What it does (never physical input) |
| --- | --- |
| `button(_:).tap()` | invokes the enabled button's action closure on the mounted instance |
| `textField(_:).setInput(_:)` | writes the mounted TextField's text binding |
| `secureField(_:).setInput(_:)` | writes the mounted SecureField's text binding |

Programmatic binding and action dispatch establishes neither physical input (key events, the field editor, first responder) nor hit testing, accessibility, or OS authentication, Keychain or biometrics. Inject a fake authenticator. ViewInspector reports the declaration content of the mounted instance, not layout or visibility; observe the AppKit hierarchy (for example, the count of `NSSecureTextField` views under `host.hostingController.view`) for rendered claims.

## The seam

The screen takes an `InspectionSeam` and subscribes with `.onReceive(seam.notice) { seam.visit(self) }`. The seam is a main-actor, single-slot rendezvous (Combine only, no continuation, no `@unchecked Sendable`). `host.inspect(seam)` waits (bounded) until the mounted instance answers, then runs your body synchronously against that live instance. Do not use ViewInspector's `ViewHosting`; Fleet owns the window.

## Queries

```swift
try await host.inspect(seam) { screen in
    let form = try screen.container("unlock-form")
    try form.secureField("Passphrase").setInput(syntheticPassphrase)
}
try await host.inspect(seam) { try $0.container("unlock-form").button("Unlock").tap() }
```

- `container(_:)` descends into the single view with an `accessibilityIdentifier`; controls match by label or title inside that scope.
- Every singular lookup requires exactly one match and throws `MacOSQueryFailure`: `.absent`, `.ambiguous` (with the count), `.disabled` (before acting), `.unsupported` (for example `MacOSInspector.unsupported("keyEvent")`, with a recommendation), `.obsolete`, or `.notMounted`.
- **Requery after state changes.** Declaration-derived facts such as `isDisabled` are read when the body is evaluated, so write a field in one inspection and tap in the next (wait for `probe(...)?.isEnabled`, as the example test does). Each inspection owns a session; a handle kept after the body returns throws `.obsolete` and cannot act on the screen that replaced the one it came from.
- `host.inspect` throws `FleetMacOSFailure(.timedOut)` when nothing answers, propagates the body's error unchanged, and propagates `CancellationError` unchanged. The seam's request slot is empty afterwards.

## Secret safety

A value passed to `setInput` is never placed in a failure description, the action trace (`session.trace` records `write binding of secure field 'Passphrase' (value withheld)`), or a binding snapshot. The adapter does not wrap ViewInspector's own errors with values either, because it only passes the value to the binding setter. Titles and labels do appear in messages; do not use a secret as a label.

## Lifetime

`FleetMacOS.withHostedView` already provides serial FIFO leases, offscreen non-key windows (the tests assert `!host.window.isKeyWindow`), bounded waits, and cleanup on return, error and cancellation. The tests cover an error thrown after interaction and a cancelled scope, each followed by a clean successor scope.

## Evidence

Sources: `Integration/MacOSConsumer/Inspection/MacOSInspection.swift` (seam, adapter) and `MacOSControlInteractionTests.swift` (synthetic unlock fixture: a SecureField bound to `@State`, an `Unlock` button that unlocks only for `SYNTHETIC_PASSPHRASE`, then a profile screen with `Switch profile`). Run with `script/check-distribution macos` (add `--allow-dirty` during development). The macOS consumer pins ViewInspector 0.10.5 (revision `2dacb6e514be19379c605a5a11564d0f3fea89d9`) and `--without-viewinspector` skips it. The suite "Mounted macOS control interaction" covers: a wrong passphrase reaching the real action and not unlocking, the correct passphrase unlocking, the old `NSSecureTextField` subtree disappearing, switching back, ambiguous/absent/disabled/unsupported/obsolete outcomes, secret absence from failures and traces, error and cancellation cleanup, and the bounded no-answer timeout.

Not claimed: macOS versions other than the one that ran the check; Toggle, Picker, menus and gestures (unsupported); anything physical.
