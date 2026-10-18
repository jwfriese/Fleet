import XCTest
@testable import Fleet

#if os(iOS)
    @testable import FleetTestApp
#elseif os(tvOS)
    @testable import FleetTestApp_tvOS
#endif

private struct EnvironmentProbeError: Error {}

private final class AppearanceProbe: UIViewController {
    var traitChanges = 0
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        traitChanges += 1
    }
}

@MainActor
class FleetEnvironmentSpec: XCTestCase {
    private var hostWindow: UIWindow!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        hostWindow = try XCTUnwrap(UIApplication.shared.keyWindow)
        smallSize = CGSize(width: hostWindow.bounds.width / 2, height: hostWindow.bounds.height / 2)
    }

    override func tearDown() async throws {
        hostWindow = nil
        try await super.tearDown()
    }

    private struct Snapshot: Equatable {
        var frame: CGRect
        var style: UIUserInterfaceStyle
        var category: UIContentSizeCategory
    }

    private func snapshot() -> Snapshot {
        Snapshot(
            frame: hostWindow.frame,
            style: hostWindow.overrideUserInterfaceStyle,
            category: hostWindow.traitCollection.preferredContentSizeCategory
        )
    }

    private var smallSize: CGSize!

    func test_configure_appliesSizeAndAppearanceToTheWindowAndItsRoot() async throws {
        let before = snapshot()
        let probe = AppearanceProbe()
        try await Fleet.withContext(window: hostWindow) { context in
            try await context.setRoot(probe)
            try await context.configure(FleetEnvironment(size: smallSize, userInterfaceStyle: .dark))
            XCTAssertEqual(hostWindow.bounds.size, smallSize)
            XCTAssertEqual(probe.view.bounds.size, smallSize)
            XCTAssertEqual(probe.traitCollection.userInterfaceStyle, .dark)
            XCTAssertEqual(context.currentEnvironment.userInterfaceStyle, .dark)
            try await context.configure(FleetEnvironment(userInterfaceStyle: .light))
            XCTAssertEqual(probe.traitCollection.userInterfaceStyle, .light)
            XCTAssertEqual(hostWindow.bounds.size, smallSize, "Unset fields are left untouched")
        }
        XCTAssertEqual(snapshot(), before)
    }

    func test_configure_appliesDynamicTypeCategory() async throws {
        guard #available(iOS 17, tvOS 17, *) else { throw XCTSkip("Per-window trait overrides need iOS/tvOS 17") }
        let before = snapshot()
        try await Fleet.withContext(window: hostWindow) { context in
            let probe = AppearanceProbe()
            try await context.setRoot(probe)
            try await context.configure(FleetEnvironment(contentSizeCategory: .accessibilityExtraExtraLarge))
            XCTAssertEqual(probe.traitCollection.preferredContentSizeCategory, .accessibilityExtraExtraLarge)
            XCTAssertTrue(probe.traitCollection.preferredContentSizeCategory.isAccessibilityCategory)
        }
        XCTAssertEqual(snapshot(), before)
        XCTAssertFalse(hostWindow.traitOverrides.contains(UITraitPreferredContentSizeCategory.self))
    }

    func test_repeatedScenarios_areDeterministic() async throws {
        let before = snapshot()
        for style in [UIUserInterfaceStyle.dark, .light, .dark] {
            try await Fleet.withContext(window: hostWindow) { context in
                XCTAssertEqual(snapshot(), before, "Each scope starts from the restored state")
                try await context.configure(FleetEnvironment(size: smallSize, userInterfaceStyle: style))
                XCTAssertEqual(context.currentEnvironment.userInterfaceStyle, style)
            }
            XCTAssertEqual(snapshot(), before)
        }
    }

    func test_environmentRestoredAfterThrownError() async throws {
        let before = snapshot()
        do {
            try await Fleet.withContext(window: hostWindow) { context in
                try await context.configure(FleetEnvironment(size: smallSize, userInterfaceStyle: .dark))
                throw EnvironmentProbeError()
            }
            XCTFail("Expected the body's error")
        } catch is EnvironmentProbeError {}
        XCTAssertEqual(snapshot(), before)
    }

    func test_environmentRestoredAfterTimeout() async throws {
        let before = snapshot()
        do {
            try await Fleet.withContext(window: hostWindow) { context in
                try await context.configure(FleetEnvironment(userInterfaceStyle: .dark))
                try await context.waitUntil("never", timeout: 0.05) { false }
            }
            XCTFail("Expected a timeout")
        } catch let failure as FleetFailure {
            XCTAssertEqual(failure.kind, .timedOut)
        }
        XCTAssertEqual(snapshot(), before)
    }

    func test_environmentRestoredAfterCancellation() async throws {
        let before = snapshot()
        let task = Task { @MainActor in
            try await Fleet.withContext(window: self.hostWindow) { context in
                try await context.configure(FleetEnvironment(size: self.smallSize, userInterfaceStyle: .dark))
                try await context.waitUntil("never", timeout: 30) { false }
            }
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        do {
            try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        XCTAssertEqual(snapshot(), before)
    }

    func test_overlappingScenarios_doNotLeakSettings() async throws {
        let before = snapshot()
        var tasks: [Task<UIUserInterfaceStyle, Error>] = []
        for style in [UIUserInterfaceStyle.dark, .light, .dark] {
            tasks.append(Task { @MainActor in
                try await Fleet.withContext(window: self.hostWindow) { context in
                    XCTAssertEqual(self.snapshot(), before, "A queued scope must not see another's settings")
                    try await context.configure(FleetEnvironment(userInterfaceStyle: style))
                    try await Task.sleep(nanoseconds: 20_000_000)
                    return context.currentEnvironment.userInterfaceStyle ?? .unspecified
                }
            })
        }
        var seen: [UIUserInterfaceStyle] = []
        for task in tasks { seen.append(try await task.value) }
        XCTAssertEqual(seen, [.dark, .light, .dark])
        XCTAssertEqual(snapshot(), before)
    }

    func test_configure_rejectsInvalidSizeBeforeChangingAnything() async throws {
        let before = snapshot()
        try await Fleet.withContext(window: hostWindow) { context in
            for size in [CGSize(width: 0, height: 100), CGSize(width: CGFloat.infinity, height: 100), CGSize(width: CGFloat.nan, height: 1)] {
                do {
                    try await context.configure(FleetEnvironment(size: size, userInterfaceStyle: .dark))
                    XCTFail("Expected invalid input for \(size)")
                } catch let failure as FleetFailure {
                    XCTAssertEqual(failure.kind, .invalidInput)
                }
            }
            XCTAssertEqual(snapshot(), before)
        }
    }

    func test_configure_afterScopeEnds_throws() async throws {
        let escaped = try await Fleet.withContext(window: hostWindow) { $0 }
        do {
            try await escaped.configure(FleetEnvironment(userInterfaceStyle: .dark))
            XCTFail("Expected invalidSetup")
        } catch let failure as FleetFailure {
            XCTAssertEqual(failure.kind, .invalidSetup)
        }
    }

    func test_ownedWindowScenario_isDismantled() async throws {
        let scene = try XCTUnwrap(hostWindow.windowScene)
        let before = snapshot()
        weak var owned: UIWindow?
        try await Fleet.withContext(scene: scene) { context in
            owned = context.window
            try await context.configure(FleetEnvironment(size: smallSize, userInterfaceStyle: .dark))
        }
        XCTAssertNil(owned?.windowScene)
        XCTAssertEqual(snapshot(), before)
    }
}
