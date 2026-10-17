# Quick start

This page is a minimal, maintained Swift Testing example. The code block below is the `quick-start` region of [`SwiftTestingConsumerTests.swift`](../Integration/PackageConsumer/SwiftTestingConsumerTests.swift), which `script/check-distribution` compiles and runs against the current package in an independent hosted consumer on iOS and tvOS. A tooling test fails if this page and that region diverge.

1. Add Fleet to your test target with Swift Package Manager ([SwiftPM installation](Installation/SwiftPM.md)). Link it to the test target only.
2. Run the tests inside an application host so a key window exists.
3. Use `Fleet.withContext(window:)` (or `withContext(scene:)`) for each test. The context serializes the whole test lifetime, waits with deadlines, and restores the host window when the body ends or throws.
4. Prefer the `...OrThrow` helpers; they report a `FleetFailure` that your framework can assert on instead of raising an exception.

```swift
@MainActor
private final class GreetingViewController: UIViewController {
    let button = UIButton(type: .system)
    private(set) var taps = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        button.addAction(UIAction { [weak self] _ in self?.taps += 1 }, for: .touchUpInside)
        view.addSubview(button)
    }
}

@MainActor
struct QuickStartTests {
    @Test func tappingTheButtonRunsItsAction() async throws {
        let host = try #require(UIApplication.shared.keyWindow)
        try await Fleet.withContext(window: host) { context in
            let controller = GreetingViewController()
            try await context.setRoot(controller)

            try controller.button.tapOrThrow()

            #expect(controller.taps == 1)
        }
    }
}
```

XCTest works the same way: call the same context APIs from an `async` test method on `@MainActor`. See [Hosting](Hosting.md) for context semantics.

## Limits

- Programmatic helpers do not prove physical hit testing, accessibility, or real keyboard presentation. Keyboard interaction is simulated through responder and control events.
- Runtime mocks instantiate a subclass of the production controller, so they do not guarantee isolation from initialization side effects (see [UIStoryboard](UIStoryboard.md)).
- Test execution stays serial; do not enable parallel UIKit testing.
- The legacy global helpers (`Fleet.setAsAppWindowRoot`, `Fleet.getApplicationScreen`) remain for existing XCTest suites and must not be mixed with contexts.
