# Mounted macOS Button, TextField, SecureField, TextEditor and Slider interaction

Platform: macOS 13+. `FleetMacOSInspection` is an optional, test-only SwiftPM product. `FleetMacOS` hosts the screen ([MacOSHosting.md](MacOSHosting.md)); this product drives the mounted controls through [ViewInspector](https://github.com/nalexn/ViewInspector), which is an implementation dependency of `FleetMacOSInspection` only. `FleetMacOS` does not link it, and a test must not import it for any supported operation. The application target imports neither Fleet nor ViewInspector and gains no runtime hook beyond a small framework-only seam (below). The product does not depend on UIKit, the `Fleet` product or `FleetRuntime`.

## Installation

```swift
.testTarget(
    name: "AppUITests",
    dependencies: [
        "AppUI",
        .product(name: "FleetMacOS", package: "Fleet"),
        .product(name: "FleetMacOSInspection", package: "Fleet"),
    ]
)
```

```swift
import FleetMacOS
import FleetMacOSInspection
```

Fleet's manifest pins ViewInspector 0.10.5, so SwiftPM resolves it for any consumer of the package; only `FleetMacOSInspection` links it.

A public AppKit route does not exist for Button: a SwiftUI `Button` is not an `NSButton`, and the hosting view exposes no accessibility press target for it. TextField and SecureField do render as AppKit text fields, but the adapter writes their SwiftUI binding directly so both control kinds share one exact-one query model.

## What it does and does not do

| Operation | What it does (never physical input) |
| --- | --- |
| `button(_:).tap()` | invokes the enabled button's action closure on the mounted instance |
| `textField(_:).setInput(_:)` | writes the mounted TextField's text binding |
| `secureField(_:).setInput(_:)` | writes the mounted SecureField's text binding |
| `textEditor(identifier:).setText(_:)` / `.text()` | writes / reads the mounted multiline TextEditor's `String` binding |
| `slider(identifier:in:).setValue(_:)` / `.value()` | writes / reads the mounted Slider's `Double` binding |

Programmatic binding and action dispatch establishes neither physical input (key events, the field editor, first responder) nor hit testing, accessibility, or OS authentication, Keychain or biometrics. Inject a fake authenticator. ViewInspector reports the declaration content of the mounted instance, not layout or visibility; observe the AppKit hierarchy (for example, the count of `NSSecureTextField` views under `host.hostingController.view`) for rendered claims.

## The seam and the endpoint

The application owns a small seam with no testing import: a main-actor, single-slot rendezvous with a Combine subject. The screen subscribes with `.onReceive(seam.notice) { seam.visit(self) }`. The test target (never the application) connects it to the product by conforming it to the public protocol, or by wrapping a closure:

```swift
@MainActor
public protocol MacOSInspectionEndpoint {
    associatedtype Screen: View
    func deliver(_ visit: @escaping @MainActor (Screen) -> Void) -> Bool
}
// or: MacOSInspectionBridge<Screen> { visit in seam.run(visit) }
```

`deliver` offers `visit` to the mounted instance, returns `true` only if an instance ran it synchronously, and must not keep `visit` afterwards. `Integration/MacOSConsumer/Inspection/InspectionSeam.swift` is the whole local support of the pinned consumer.

`host.inspect(endpoint, timeout:)` waits for the endpoint to deliver the mounted screen, then runs the body synchronously with that instance. If the endpoint never answers by the deadline, it throws `MacOSQueryFailure.notMounted(screen:)`. A non-finite timeout throws `FleetMacOSFailure` with kind `.invalidInput`, and an ended host throws `.invalidSetup`. Cancellation and errors from the body propagate unchanged. `host.probe(endpoint) { ... }` runs synchronously for observations inside a `waitForUpdate` condition and returns `nil` if the scope ended, the endpoint did not answer, or the body threw. Fleet owns the window and hosting lifecycle. Do not use ViewInspector's `ViewHosting`.

Public types: `MacOSInspector` (queries: `container`, `button`, `textField`, `secureField`, `textEditor(identifier:)`), `MacOSButtonHandle`, `MacOSTextInputHandle`, `MacOSTextEditorHandle`, `MacOSQueryFailure` (`absent`, `ambiguous`, `disabled`, `unsupported`, `obsolete`, `notMounted`) and `MacOSActionKind`. Handles are valid only inside the inspection closure that produced them; requery after state changes.

## `container(_:)`

```swift
func container(_ identifier: String) throws -> MacOSInspector
```

Returns an inspector scoped to the sole view whose `accessibilityIdentifier` matches. Each container and control query first checks its inspection is still active, throwing `MacOSQueryFailure.obsolete` after the inspection body returns. Within the current scope, zero matches throw `.absent` and more than one throws `.ambiguous` with the count. Use a container to isolate a row before querying a control repeated in several rows.

## `button(_:)` and `button(identifier:)`

```swift
func button(_ label: String) throws -> MacOSButtonHandle
func button(identifier: String) throws -> MacOSButtonHandle
```

Finds one Button by its text label or accessibility identifier. The handle exposes `isEnabled`. `tap()` checks the inspection and throws `.disabled` before invoking a disabled button's action. For an enabled button, it invokes the action closure once and returns `.invokesClosure`.

## `textField(_:)` and `textField(identifier:)`

```swift
func textField(_ title: String) throws -> MacOSTextInputHandle
func textField(identifier: String) throws -> MacOSTextInputHandle
```

Finds one TextField by title or accessibility identifier. The handle exposes `isEnabled`. `setInput(_:)` checks the inspection and throws `.disabled` before writing to a disabled field. For an enabled field, it replaces the bound string and returns `.writesBinding`. Pass `""` to clear it.

## `secureField(_:)` and `secureField(identifier:)`

```swift
func secureField(_ title: String) throws -> MacOSTextInputHandle
func secureField(identifier: String) throws -> MacOSTextInputHandle
```

Finds one SecureField by title or accessibility identifier. The handle checks and writes the binding in the same order as the TextField handle. The entered value is withheld from the action trace and failure descriptions.

Inspect again after state changes. For example, write a field in one inspection, wait for the button to become enabled using `probe`, and tap it in a fresh inspection.

## Multiline TextEditor

```swift
func textEditor(identifier: String) throws -> MacOSTextEditorHandle
func text() throws -> String
func setText(_ value: String) throws -> MacOSActionKind
var isEnabled: Bool { get }
```

A TextEditor has no label, so it is found by `accessibilityIdentifier` and must match exactly once in the inspector's scope (`container(_:)` narrows it). `setText` replaces the whole bound string in one step, so `"line one\n\nline three\n"` reaches the binding with every newline intact, and `""` clears it. `text()` reads the value held by the mounted instance's binding. The tests then press `Save answer` to prove the application's own action sees the written value, and press `Switch project` to prove the screen's reset reaches the editor.

Failures use `MacOSQueryFailure`: `.absent` and `.ambiguous` (with the count) from the lookup, `.disabled` from `setText` before writing (`text()` still reads), `.obsolete` for a handle used after its inspection ended, and `.unsupported` when the editor's binding cannot be read or written as a plain `String` (for example an attributed-text binding). Nothing is simulated in that case. `setText` records `write binding of text editor '<id>' (value withheld)` in the trace.

The write is a programmatic binding dispatch. It does not type, move the caret or selection, present a keyboard, run the field editor or an undo stack, hit test, or establish accessibility. Declared state is read when the body is evaluated, so write in one inspection and read or tap in the next. A handle never survives its inspection, so after a project or screen replacement query again from a fresh `host.inspect`; an old handle throws `.obsolete` and cannot edit the successor.

## Example

`PlaybackScreen` in the macOS consumer has two recording rows, each with a Button labelled `Play` and identified as `recording.play`. This test selects the second row first, then finds the first row's button by label.

```swift
let seam = InspectionSeam<PlaybackScreen>()
var played: [Int] = []
try await FleetMacOS.withHostedView(PlaybackScreen(seam: seam, play: { played.append($0) })) { host in
    try await host.waitUntilReady()
    try await host.inspect(seam) { screen in
        let row = try screen.container("recording.second")
        try row.button(identifier: "recording.play").tap()
    }
    try await host.inspect(seam) { try $0.container("recording.first").button("Play").tap() }
    #expect(played == [2, 1])
}
```

## Slider

```swift
func slider(identifier: String, in range: ClosedRange<Double>) throws -> MacOSSliderHandle // on MacOSInspector
func value() throws -> Double                                     // on MacOSSliderHandle
func setValue(_ value: Double) throws -> MacOSActionKind          // on MacOSSliderHandle
var isEnabled: Bool                                               // on MacOSSliderHandle
```

A Slider is found by `accessibilityIdentifier` and must match exactly once in the inspector's scope (`container(_:)` narrows it). `setValue` calls the slider's binding setter once with the given number, so an application binding such as `Binding(get: { player.position }, set: { player.seek(to: $0) })` runs its real seek action with that value. `value()` reads what the binding's getter reports for the mounted instance. ViewInspector reports the slider's binding normalized to 0...1 and not its declared range, so you pass the slider's `in:` range and the adapter converts both ways. A value outside that range throws `.unsupported` before the setter runs. The adapter does not enforce `step`; the application owns seek limits, so test them in the domain layer.

Failures use `MacOSQueryFailure`: `.absent` and `.ambiguous` (with the count) from the lookup, `.disabled` from `setValue` before the setter runs (`value()` still reads), `.obsolete` for a handle used after its inspection ended, and `.unsupported` when the binding cannot be read or written as a `Double`. Nothing is simulated in that case. `setValue` records `write binding of slider '<id>' to <value>` in the trace.

This is programmatic binding dispatch. It does not drag the thumb, hit test, run tracking events, play audio, request microphone permission, or establish accessibility. Use a fake player. Write in one inspection and read in the next, because a handle never survives its inspection; after a screen replacement, query again, since an old handle throws `.obsolete` and cannot seek the successor.

## Secret safety

A value passed to `setInput` is never placed in a failure description, the action trace (`session.trace` records `write binding of secure field 'Passphrase' (value withheld)`), or a binding snapshot. The adapter does not wrap ViewInspector's own errors with values either, because it only passes the value to the binding setter. Titles and labels do appear in messages; do not use a secret as a label.

## Lifetime

`FleetMacOS.withHostedView` already provides serial FIFO leases, offscreen non-key windows (the tests assert `!host.window.isKeyWindow`), bounded waits, and cleanup on return, error and cancellation. The tests cover an error thrown after interaction and a cancelled scope, each followed by a clean successor scope.

## Evidence

Sources: `FleetMacOSInspection/FleetMacOSInspection.swift` (the adapter), `Integration/MacOSConsumer/Inspection/InspectionSeam.swift` (the consumer's seam and endpoint conformance) and `MacOSControlInteractionTests.swift` (synthetic unlock fixture: a SecureField bound to `@State`, an `Unlock` button that unlocks only for `SYNTHETIC_PASSPHRASE`, then a profile screen with `Switch profile`). `MacOSSliderInteractionTests.swift` adds the "Mounted macOS Slider interaction" suite (a synthetic replay transport with a fake player: seek value reaching the setter, requery, ambiguous/absent/disabled/obsolete outcomes with no seek, and a handle from an ended scope failing against a successor). `MacOSTextEditorInteractionTests.swift` adds the "Mounted macOS TextEditor interaction" suite (a synthetic practice form: a TextEditor bound to `@State`, `Save answer` and `Switch project` buttons), covering newline-preserving replacement and clearing, the saved value, the cleared editor after switching, ambiguous/absent/disabled/obsolete outcomes, and a handle kept from an ended scope failing against a successor scope. Run with `script/check-distribution macos` (add `--allow-dirty` during development). The macOS consumer depends only on the Git-pinned `FleetMacOS` and `FleetMacOSInspection` products, imports no ViewInspector and uses no `@testable import`; the resolved lockfile pins ViewInspector 0.10.5 (revision `2dacb6e514be19379c605a5a11564d0f3fea89d9`) as the adapter's dependency, and `--without-viewinspector` leaves the inspection suites and product out. The suite "Mounted macOS control interaction" covers: a wrong passphrase reaching the real action and not unlocking, the correct passphrase unlocking, the old `NSSecureTextField` subtree disappearing, switching back, ambiguous/absent/disabled/unsupported/obsolete outcomes, secret absence from failures and traces, error and cancellation cleanup, and the bounded no-answer timeout.

The identifier tests dispatch each repeated Play button in its own row, verify the TextField and SecureField queries match only their own control type, and check enabled and disabled binding writes. The inspection wait tests distinguish a missing mounted answer from an invalid deadline, cancellation, and a timeout error thrown by the inspection body itself.

Not claimed: macOS versions other than the one that ran the check; Toggle, Picker, menus and gestures (unsupported); attributed-text TextEditor bindings; Slider dragging, step enforcement, a range that differs from the one you pass, and audio playback; caret, selection and undo behavior of the TextEditor; anything physical.
