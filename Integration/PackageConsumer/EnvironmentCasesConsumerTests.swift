import SwiftUI
import UIKit
import XCTest
import Fleet

// MARK: - Injected inputs

/// Localized strings supplied by the test. Nothing reads process-wide language, region or
/// accessibility settings; every locale-dependent value comes from these explicit inputs.
struct RecipeStrings: Equatable, Sendable {
    var quantityLabel: String
}

/// Records what the *mounted* screen observed, so assertions do not depend on a second instance.
@MainActor
final class RecipeProbe {
    var quantityFrame: CGRect = .zero
    var colorScheme: ColorScheme?
    var layoutDirection: LayoutDirection?
}

private struct QuantityFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

struct RecipeCard: View {
    let name: String
    let quantity: Int
    let strings: RecipeStrings
    let locale: Locale
    let probe: RecipeProbe
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.headline)
            HStack {
                Text(strings.quantityLabel)
                Spacer()
                Text(quantity.formatted(.number.locale(locale)))
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: QuantityFrameKey.self, value: proxy.frame(in: .global))
                    })
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .black : .white }))
        .onPreferenceChange(QuantityFrameKey.self) { frame in
            MainActor.assumeIsolated { probe.quantityFrame = frame }
        }
        .onAppear { probe.colorScheme = colorScheme; probe.layoutDirection = layoutDirection }
        .onChange(of: colorScheme) { probe.colorScheme = $0 }
        .onChange(of: layoutDirection) { probe.layoutDirection = $0 }
    }
}

// MARK: - Named-case driver

/// One named environment. `environment` is window-scoped (Fleet restores it); `locale` and
/// `layoutDirection` are injected into the SwiftUI tree only.
struct EnvironmentCase {
    var name: String
    var environment: FleetEnvironment
    var locale: Locale = Locale(identifier: "en_US")
    var layoutDirection: LayoutDirection = .leftToRight
    var recipeName: String = "Soup"
    var quantity: Int = 2
    var strings = RecipeStrings(quantityLabel: "Servings")
}

/// What accompanies every assertion and artifact for a case.
struct CaseReport {
    let name: String
    let resolved: FleetEnvironment
    let features: String

    /// A stable prefix for assertion messages, snapshot names and artifact file names.
    var label: String { "[case \(name) | resolved \(resolved) | features \(features)]" }
    var artifactName: String {
        String(name.map { $0.isLetter || $0.isNumber ? $0 : "-" })
    }
}

enum EnvironmentCases {
    static let phone = CGSize(width: 320, height: 480)

    static var traitOverridesAvailable: Bool {
        if #available(iOS 17, tvOS 17, *) { return true }
        return false
    }

    /// The maintained small set: long name + large quantity, appearance, Dynamic Type, and
    /// injected Arabic/RTL. The Arabic-Indic digits come from the injected locale only.
    static var standard: [EnvironmentCase] {
        // tvOS does not apply the Dynamic Type category override to the hosted content (observed: identical
        // fitted height and image), so the large-text case is iOS-only rather than a false tvOS claim.
        let long = "Slow-braised wild mushroom and barley soup with roasted garlic and thyme"
        var cases = [
            EnvironmentCase(name: "light", environment: FleetEnvironment(size: phone, userInterfaceStyle: .light),
                            recipeName: long, quantity: 1_234_567),
            EnvironmentCase(name: "dark", environment: FleetEnvironment(size: phone, userInterfaceStyle: .dark),
                            recipeName: long, quantity: 1_234_567),
            EnvironmentCase(name: "arabic rtl", environment: FleetEnvironment(size: phone, userInterfaceStyle: .light),
                            locale: Locale(identifier: "ar_EG"), layoutDirection: .rightToLeft,
                            recipeName: "شوربة الفطر", quantity: 1_234_567, strings: RecipeStrings(quantityLabel: "الحصص")),
        ]
        #if !os(tvOS)
        cases.insert(EnvironmentCase(name: "large text", environment: FleetEnvironment(
                         size: phone, userInterfaceStyle: .light, contentSizeCategory: .accessibilityExtraExtraExtraLarge),
                     recipeName: long, quantity: 1_234_567), at: 2)
        #endif
        return cases
    }

    /// Runs each case in its own sequential `withHostedView` scope (never nested), so the
    /// window, root and trait overrides are restored before the next case starts, on return,
    /// error and cancellation alike. `body` receives the mounted handle (not a second instance),
    /// the report, and the mounted screen's probe, after an explicit readiness wait.
    ///
    /// The first error stops the run after that case's cleanup; its message carries the case label.
    @MainActor
    static func run(
        _ cases: [EnvironmentCase],
        window: UIWindow,
        _ body: @MainActor (FleetHostedView, CaseReport, RecipeProbe) async throws -> Void
    ) async throws {
        for item in cases {
            let probe = RecipeProbe()
            let view = RecipeCard(name: item.recipeName, quantity: item.quantity, strings: item.strings,
                                  locale: item.locale, probe: probe)
                .environment(\.locale, item.locale)
                .environment(\.layoutDirection, item.layoutDirection)
            do {
                try await Fleet.withHostedView(view, window: window) { host in
                    try await host.context.configure(item.environment)
                    if let size = item.environment.size {
                        try await host.context.waitUntil("hosting view to adopt \(size) for case \(item.name)") {
                            host.isReady && host.hostingController.view.bounds.size == size
                        }
                    }
                    let report = CaseReport(
                        name: item.name, resolved: host.context.currentEnvironment,
                        features: "traitOverrides=\(traitOverridesAvailable), injectedLocale=\(item.locale.identifier), "
                            + "injectedLayoutDirection=\(item.layoutDirection == .rightToLeft ? "rtl" : "ltr")")
                    try await body(host, report, probe)
                }
            } catch let failure as FleetFailure {
                throw CaseFailure(label: item.name, underlying: failure)
            }
        }
    }
}

/// Keeps the case identity with a Fleet failure without altering the underlying error.
struct CaseFailure: Error, CustomStringConvertible {
    let label: String
    let underlying: FleetFailure
    var description: String { "case \(label): \(underlying)" }
}

// MARK: - Direct (library-free) oracle

@MainActor
final class EnvironmentCasesConsumerTests: XCTestCase {
    private func keyWindow() throws -> UIWindow {
        try XCTUnwrap(UIApplication.shared.keyWindow)
    }

    private struct Boundary: Equatable {
        var frame: CGRect
        var style: UIUserInterfaceStyle
        var root: ObjectIdentifier?
        var contentSize: UIContentSizeCategory
    }

    private func boundary(_ window: UIWindow) -> Boundary {
        Boundary(frame: window.frame, style: window.overrideUserInterfaceStyle,
                 root: window.rootViewController.map(ObjectIdentifier.init),
                 contentSize: window.traitCollection.preferredContentSizeCategory)
    }

    /// Bounded main-actor poll for state outside any context (the driver owns the lease).
    private func pollMainActor(timeout: TimeInterval = 5, _ condition: @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            try Task.checkCancellation()
            guard Date() < deadline else { XCTFail("first case was never mounted"); throw CancellationError() }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func requireOverrides() throws {
        guard EnvironmentCases.traitOverridesAvailable else { throw XCTSkip("Per-window trait overrides need iOS/tvOS 17.") }
    }

    func test_standardCases_resolveInjectedInputsOnTheMountedScreen() async throws {
        try requireOverrides()
        let window = try keyWindow()
        var seen: [String] = []
        try await EnvironmentCases.run(EnvironmentCases.standard, window: window) { host, report, probe in
            seen.append(report.name)
            XCTAssertTrue(host.isMounted, report.label)
            XCTAssertEqual(host.hostingController.view.window, window, report.label)
            XCTAssertEqual(report.resolved.size, EnvironmentCases.phone, report.label)
            let expectedStyle: UIUserInterfaceStyle = report.name == "dark" ? .dark : .light
            XCTAssertEqual(report.resolved.userInterfaceStyle, expectedStyle, report.label)
            XCTAssertEqual(probe.colorScheme, expectedStyle == .dark ? .dark : .light, report.label)
            if report.name == "large text" {
                XCTAssertEqual(report.resolved.contentSizeCategory, .accessibilityExtraExtraExtraLarge, report.label)
            }
            // Each case starts from the baseline: no leaked large text or dark style.
            if report.name != "large text" {
                XCTAssertNotEqual(report.resolved.contentSizeCategory, .accessibilityExtraExtraExtraLarge, report.label)
            }
            let rtl = report.name == "arabic rtl"
            XCTAssertEqual(probe.layoutDirection, rtl ? .rightToLeft : .leftToRight, report.label)
            // The quantity is trailing: right of centre when LTR, left of centre when RTL.
            let midX = EnvironmentCases.phone.width / 2
            XCTAssertEqual(probe.quantityFrame.midX > midX, !rtl, "\(report.label) quantity frame \(probe.quantityFrame)")
            // Injected direction is SwiftUI-only: UIKit's own direction for the hosting view is unchanged.
            XCTAssertEqual(host.hostingController.view.effectiveUserInterfaceLayoutDirection,
                           window.effectiveUserInterfaceLayoutDirection, report.label)
        }
        XCTAssertEqual(seen, EnvironmentCases.standard.map(\.name))
    }

    func test_largeTextWrapsLongNames_withoutLeakingToTheNextCase() async throws {
        try requireOverrides()
        #if os(tvOS)
        throw XCTSkip("tvOS does not apply the Dynamic Type override to hosted content; the case is iOS-only.")
        #endif
        let window = try keyWindow()
        var heights: [String: CGFloat] = [:]
        let cases = EnvironmentCases.standard.filter { ["light", "large text"].contains($0.name) }
        try await EnvironmentCases.run(cases, window: window) { host, report, _ in
            let fitted = host.hostingController.sizeThatFits(in: CGSize(width: EnvironmentCases.phone.width, height: .greatestFiniteMagnitude))
            heights[report.name] = fitted.height
        }
        let light = try XCTUnwrap(heights["light"]), large = try XCTUnwrap(heights["large text"])
        XCTAssertGreaterThan(large, light, "large text should need more height than the default size")
    }

    func test_boundaryIsRestoredAfterRunErrorAndCancellation() async throws {
        try requireOverrides()
        let window = try keyWindow()
        let before = boundary(window)

        struct Boom: Error {}
        do {
            try await EnvironmentCases.run(EnvironmentCases.standard, window: window) { _, report, _ in
                if report.name == "dark" { throw Boom() }
            }
            XCTFail("expected the body error")
        } catch is Boom {}
        XCTAssertEqual(boundary(window), before, "an error mid-run must not leak a case's environment")

        let task = Task { @MainActor in
            try await EnvironmentCases.run(EnvironmentCases.standard, window: window) { _, _, _ in
                try await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
        // Cancel only once the first case is mounted, so cleanup (not setup) is what is exercised.
        try await pollMainActor { window.rootViewController is UIHostingController<AnyView> }
        task.cancel()
        do {
            try await task.value
            XCTFail("expected cancellation")
        } catch is CancellationError {}
        XCTAssertEqual(boundary(window), before, "cancellation must restore the window")
    }

    func test_failureCarriesCaseIdentity() async throws {
        let window = try keyWindow()
        let bad = EnvironmentCase(name: "bad size", environment: FleetEnvironment(size: CGSize(width: -1, height: 10)))
        do {
            try await EnvironmentCases.run([bad], window: window) { _, _, _ in XCTFail("must not run") }
            XCTFail("expected failure")
        } catch let failure as CaseFailure {
            XCTAssertEqual(failure.label, "bad size")
            XCTAssertEqual(failure.underlying.kind, .invalidInput)
            XCTAssertTrue(failure.description.contains("bad size"))
        }
    }
}
