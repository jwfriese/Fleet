import SwiftUI
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

    // MARK: Size classes, adaptive layout, hosting

    private final class AdaptiveProbe: UIViewController {
        let label = UILabel()
        var compactHorizontal = false
        override func viewDidLoad() {
            super.viewDidLoad()
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
            label.font = UIFont.preferredFont(forTextStyle: .body)
            label.text = "A reasonably long line of text that wraps when type grows large enough to matter."
            view.addSubview(label)
        }
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            compactHorizontal = traitCollection.horizontalSizeClass == .compact
            let width = compactHorizontal ? view.bounds.width / 2 : view.bounds.width
            label.frame = CGRect(origin: .zero, size: label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)))
        }
    }

    func test_configure_sizeClassesReachDescendantsAndAreRestored() async throws {
        guard #available(iOS 17, tvOS 17, *) else { throw XCTSkip("Per-window trait overrides need iOS/tvOS 17") }
        let probe = AdaptiveProbe()
        let before = hostWindow.traitCollection
        try await Fleet.withContext(window: hostWindow) { context in
            try await context.setRoot(probe)
            try await context.configure(FleetEnvironment(horizontalSizeClass: .compact, verticalSizeClass: .regular))
            XCTAssertEqual(probe.traitCollection.horizontalSizeClass, .compact)
            XCTAssertEqual(probe.traitCollection.verticalSizeClass, .regular)
            XCTAssertEqual(context.currentEnvironment.horizontalSizeClass, .compact)
            XCTAssertTrue(probe.compactHorizontal)
            try await context.configure(FleetEnvironment(horizontalSizeClass: .regular))
            XCTAssertEqual(probe.traitCollection.horizontalSizeClass, .regular)
            XCTAssertEqual(probe.traitCollection.verticalSizeClass, .regular, "Unset fields are untouched")
            try await context.waitUntil("regular layout", timeout: 2) { !probe.compactHorizontal }
        }
        XCTAssertEqual(hostWindow.traitCollection.horizontalSizeClass, before.horizontalSizeClass)
        XCTAssertEqual(hostWindow.traitCollection.verticalSizeClass, before.verticalSizeClass)
        XCTAssertFalse(hostWindow.traitOverrides.contains(UITraitHorizontalSizeClass.self))
        XCTAssertFalse(hostWindow.traitOverrides.contains(UITraitVerticalSizeClass.self))
    }

    func test_configure_restoresPreexistingSizeClassOverride() async throws {
        guard #available(iOS 17, tvOS 17, *) else { throw XCTSkip("Per-window trait overrides need iOS/tvOS 17") }
        hostWindow.traitOverrides.horizontalSizeClass = .compact
        defer { hostWindow.traitOverrides.remove(UITraitHorizontalSizeClass.self) }
        try await Fleet.withContext(window: hostWindow) { context in
            try await context.configure(FleetEnvironment(horizontalSizeClass: .regular))
            try await context.configure(FleetEnvironment(horizontalSizeClass: .regular))
            XCTAssertEqual(hostWindow.traitCollection.horizontalSizeClass, .regular)
        }
        XCTAssertTrue(hostWindow.traitOverrides.contains(UITraitHorizontalSizeClass.self))
        XCTAssertEqual(hostWindow.traitOverrides.horizontalSizeClass, .compact)
        XCTAssertEqual(hostWindow.traitCollection.horizontalSizeClass, .compact)
    }

    func test_configure_rejectsUnspecifiedSizeClassBeforeChangingAnything() async throws {
        try await Fleet.withContext(window: hostWindow) { context in
            let before = snapshot()
            do {
                try await context.configure(FleetEnvironment(userInterfaceStyle: .dark, horizontalSizeClass: .unspecified))
                XCTFail("Expected invalid input")
            } catch let failure as FleetFailure {
                XCTAssertEqual(failure.kind, .invalidInput)
            }
            XCTAssertEqual(snapshot(), before)
        }
    }

    func test_configure_dynamicTypeChangesTextLayoutAfterHosting() async throws {
        #if os(tvOS)
            throw XCTSkip("tvOS fonts do not scale with the Dynamic Type category")
        #endif
        guard #available(iOS 17, tvOS 17, *) else { throw XCTSkip("Per-window trait overrides need iOS/tvOS 17") }
        let probe = AdaptiveProbe()
        try await Fleet.withContext(window: hostWindow) { context in
            try await context.setRoot(probe)
            try await context.configure(FleetEnvironment(contentSizeCategory: .extraSmall))
            let fit = CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude)
            let smallHeight = probe.label.sizeThatFits(fit).height
            try await context.configure(FleetEnvironment(contentSizeCategory: .accessibilityExtraExtraExtraLarge))
            XCTAssertGreaterThan(probe.label.sizeThatFits(fit).height, smallHeight, "Larger type wraps to a taller label")
        }
    }

    private struct HostedProbeView: View {
        @Environment(\.colorScheme) var scheme
        @Environment(\.horizontalSizeClass) var horizontal
        @Environment(\.sizeCategory) var category
        let report: (ColorScheme, UserInterfaceSizeClass?, ContentSizeCategory) -> Void
        var body: some View {
            report(scheme, horizontal, category)
            return Text("hosted")
        }
    }

    func test_configure_propagatesAcrossUIKitSwiftUIBoundary() async throws {
        guard #available(iOS 17, tvOS 17, *) else { throw XCTSkip("Per-window trait overrides need iOS/tvOS 17") }
        var latest: (ColorScheme, UserInterfaceSizeClass?, ContentSizeCategory)?
        let hosting = UIHostingController(rootView: HostedProbeView { latest = ($0, $1, $2) })
        let container = UIViewController()
        container.addChild(hosting)
        container.view.addSubview(hosting.view)
        hosting.view.frame = container.view.bounds
        hosting.didMove(toParent: container)
        try await Fleet.withContext(window: hostWindow) { context in
            try await context.setRoot(container)
            try await context.configure(FleetEnvironment(
                userInterfaceStyle: .dark,
                contentSizeCategory: .accessibilityLarge,
                horizontalSizeClass: .compact))
            #if os(iOS)
                try await context.waitUntil("SwiftUI content to observe the environment", timeout: 5) {
                    latest?.0 == .dark && latest?.1 == .compact && latest?.2 == .accessibilityLarge
                }
            #else
                // SwiftUI does not surface size classes or Dynamic Type through its tvOS environment.
                try await context.waitUntil("SwiftUI content to observe the appearance", timeout: 5) {
                    latest?.0 == .dark
                }
            #endif
            XCTAssertEqual(hosting.traitCollection.userInterfaceStyle, .dark)
        }
    }

    func test_waitTimeout_includesResolvedEnvironment() async throws {
        do {
            try await Fleet.withContext(window: hostWindow) { context in
                try await context.configure(FleetEnvironment(userInterfaceStyle: .dark))
                try await context.waitUntil("never", timeout: 0.05) { false }
            }
            XCTFail("Expected a timeout")
        } catch let failure as FleetFailure {
            XCTAssertTrue("\(failure)".contains("Resolved environment"), "\(failure)")
            XCTAssertTrue("\(failure)".contains("horizontalSizeClass="), "\(failure)")
        }
    }
}
