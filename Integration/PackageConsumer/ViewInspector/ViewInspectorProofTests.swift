import Combine
import SwiftUI
import Testing
import UIKit
import XCTest
import Fleet
import ViewInspector

// MARK: - Application seam (no ViewInspector import needed)

/// The only application-side seam: a main-actor rendezvous that the *mounted* screen answers.
///
/// The screen subscribes to `notice` with `onReceive` and hands its live `self` to `visit`.
/// A request is single-slot and is always cleared by `run`, whether or not a mounted instance
/// answered, so no callback outlives the request that registered it. No continuation is used.
@MainActor
final class InspectionSeam<V: View> {
    let notice = PassthroughSubject<Void, Never>()
    private var pending: (@MainActor (V) -> Void)?
    var hasPendingRequest: Bool { pending != nil }

    func visit(_ view: V) {
        let request = pending
        pending = nil
        request?(view)
    }

    /// Delivers `request` to the mounted instance synchronously. Returns `false` (having
    /// released the request) when no mounted instance is subscribed.
    func run(_ request: @escaping @MainActor (V) -> Void) -> Bool {
        var answered = false
        pending = { view in answered = true; request(view) }
        notice.send()
        pending = nil
        return answered
    }
}

@MainActor
final class CounterModel: ObservableObject {
    @Published var taps = 0
    var appearances = 0
}

struct CounterScreen: View {
    @EnvironmentObject var model: CounterModel
    @State private var label = "idle"
    let seam: InspectionSeam<CounterScreen>

    var body: some View {
        VStack {
            Text(label)
            Text("taps: \(model.taps)")
            Button("Tap") {
                label = "tapped"
                model.taps += 1
            }
        }
        .onAppear { model.appearances += 1 }
        .onReceive(seam.notice) { seam.visit(self) }
    }
}

// MARK: - Test-side bounded inspection

private struct Observed<T> {
    var value: T?
    var error: Error?
}

/// Inspects the mounted instance, bounded by `timeout`. Waiting is Fleet's condition poll, so a
/// timeout is a `FleetFailure(.timedOut)`, cancellation is the unchanged `CancellationError`,
/// and an error thrown by `body` (for example ViewInspector's `InspectionError`) is rethrown
/// unchanged. The seam's request slot is empty on every exit.
@MainActor
private func inspectMounted<T>(
    _ seam: InspectionSeam<CounterScreen>,
    in context: FleetTestContext,
    timeout: TimeInterval = 2,
    _ body: @escaping @MainActor (InspectableView<ViewType.ClassifiedView>) throws -> T
) async throws -> T {
    var observed = Observed<T>()
    try await context.waitUntil("mounted CounterScreen to answer inspection", timeout: timeout) {
        seam.run { view in
            do { observed.value = try body(try view.inspect()) } catch { observed.error = error }
        }
    }
    if let error = observed.error { throw error }
    return observed.value!
}

private func texts(_ view: InspectableView<ViewType.ClassifiedView>) throws -> [String] {
    let stack = try view.vStack()
    return [try stack.text(0).string(), try stack.text(1).string()]
}

private func windowIDs(_ scene: UIWindowScene) -> [ObjectIdentifier] {
    scene.windows.map(ObjectIdentifier.init)
}

// MARK: - Swift Testing

@MainActor
@Suite("ViewInspector inspects the Fleet-owned screen (Swift Testing)")
struct ViewInspectorOwnershipTests {
    private func hostWindow() throws -> UIWindow {
        try #require(UIApplication.shared.keyWindow)
    }

    @Test func scopedHandle_realButtonTapUpdatesTheSameMountedScreen() async throws {
        let model = CounterModel()
        let seam = InspectionSeam<CounterScreen>()
        try await Fleet.withHostedView(CounterScreen(seam: seam).environmentObject(model), window: try hostWindow()) { host in
            try await inspectMounted(seam, in: host.context) { try $0.vStack().button(2).tap() }
            #expect(model.taps == 1)
            try await host.waitForUpdate("re-rendered text is inspectable") {
                currentTexts(seam) == ["tapped", "taps: 1"]
            }
            #expect(host.lifecycle.count(of: .appeared) == 1)
        }
    }

    @Test func actionAndUpdateHappenOnTheSameMountedInstanceInFleetsWindow() async throws {
        let host = try hostWindow()
        let scene = try #require(host.windowScene)
        let windowsBefore = windowIDs(scene)
        let model = CounterModel()
        let seam = InspectionSeam<CounterScreen>()
        let hosting = UIHostingController(rootView: CounterScreen(seam: seam).environmentObject(model))
        try await Fleet.withContext(window: host) { context in
            try await context.setRoot(hosting)
            // Fleet owns the host; no second window or key window appeared.
            #expect(context.window === host)
            #expect(hosting.view.window === host)
            #expect(windowIDs(scene) == windowsBefore)
            #expect(UIApplication.shared.keyWindow === host)

            let initial = try await inspectMounted(seam, in: context) { try texts($0) }
            #expect(initial == ["idle", "taps: 0"])

            // Operate the real screen action through the inspector.
            try await inspectMounted(seam, in: context) { try $0.vStack().button(2).tap() }
            #expect(model.taps == 1)

            // A subsequent update is observed on the same mounted instance.
            try await context.waitUntil("re-rendered state is inspectable") {
                currentTexts(seam) == ["tapped", "taps: 1"]
            }
            #expect(model.appearances == 1, "the screen was mounted exactly once")
            #expect(hosting.view.window === host)
            #expect(windowIDs(scene) == windowsBefore)
        }
        #expect(!seam.hasPendingRequest)
    }

    @Test func detachedValueCopiesAreNotTheMountedInstance() async throws {
        let host = try hostWindow()
        let model = CounterModel()
        let seam = InspectionSeam<CounterScreen>()
        try await Fleet.withContext(window: host) { context in
            try await context.setRoot(UIHostingController(rootView: CounterScreen(seam: seam).environmentObject(model)))
            // An unmounted copy has its own (absent) state graph and never answers the seam.
            let otherSeam = InspectionSeam<CounterScreen>()
            let detachedModel = CounterModel()
            let detached = CounterScreen(seam: otherSeam).environmentObject(detachedModel)
            #expect(otherSeam.run { _ in } == false)
            try detached.inspect().find(button: "Tap").tap()
            #expect(detachedModel.taps == 1, "the detached copy acts on its own injected model")
            #expect(model.taps == 0)
            #expect(!otherSeam.hasPendingRequest)
        }
    }

    @Test func unmountedScreenTimesOutWithATypedFailureAndReleasesTheRequest() async throws {
        let host = try hostWindow()
        let seam = InspectionSeam<CounterScreen>()
        let failure = await #expect(throws: FleetFailure.self) {
            try await Fleet.withContext(window: host) { context in
                try await inspectMounted(seam, in: context, timeout: 0.1) { _ in 0 }
            }
        }
        #expect(failure?.kind == .timedOut)
        #expect(!seam.hasPendingRequest)
    }

    @Test func inspectionErrorsPropagateUnchangedAndReleaseTheRequest() async throws {
        let host = try hostWindow()
        let seam = InspectionSeam<CounterScreen>()
        let model = CounterModel()
        await #expect(throws: InspectionError.self) {
            try await Fleet.withContext(window: host) { context in
                try await context.setRoot(UIHostingController(rootView: CounterScreen(seam: seam).environmentObject(model)))
                try await inspectMounted(seam, in: context) { try $0.vStack().button(9) }
            }
        }
        #expect(!seam.hasPendingRequest)
    }

    @Test func cancellationPropagatesAndReleasesTheRequest() async throws {
        let host = try hostWindow()
        let seam = InspectionSeam<CounterScreen>()
        let task = Task { @MainActor in
            try await Fleet.withContext(window: host) { context in
                try await inspectMounted(seam, in: context, timeout: 30) { _ in 0 }
            }
        }
        await Task.yield()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(!seam.hasPendingRequest)
    }

    /// Contrast, not integration: ViewInspector's own hosting creates a second window, so using
    /// it alongside a Fleet context would not inspect the Fleet-owned screen.
    @Test func viewInspectorsOwnHostingIsADifferentWindow() async throws {
        let host = try hostWindow()
        let scene = try #require(host.windowScene)
        let model = CounterModel()
        let seam = InspectionSeam<CounterScreen>()
        let view = CounterScreen(seam: seam).environmentObject(model)
        // ViewInspector caches its window in a static property and only shows it when first created, so on
        // a repeated run it is already attached (and hidden by the cleanup below). Assert on attachment to
        // the scene, not visibility, and hide it again afterwards.
        func foreignWindows() -> [UIWindow] {
            scene.windows.filter { $0 !== host }
        }
        defer { foreignWindows().forEach { $0.isHidden = true } }
        try await Fleet.withContext(window: host) { _ in
            ViewHosting.host(view: view)
            defer { ViewHosting.expel() }
            #expect(!foreignWindows().isEmpty, "ViewHosting.host uses its own window, not the Fleet host")
        }
        // Observed with 0.10.5: `expel()` does not detach ViewInspector's window from the scene.
        #expect(!foreignWindows().isEmpty)
    }
}

/// Reads the current texts through the seam without suspending; `nil` while nothing answers.
@MainActor
private func currentTexts(_ seam: InspectionSeam<CounterScreen>) -> [String]? {
    var result: [String]?
    _ = seam.run { view in result = try? texts(view.inspect()) }
    return result
}

// MARK: - XCTest

@MainActor
final class ViewInspectorOwnershipXCTests: XCTestCase {
    func test_scopedHandle_realButtonTapUpdatesTheSameMountedScreen() async throws {
        let host = try XCTUnwrap(UIApplication.shared.keyWindow)
        let model = CounterModel()
        let seam = InspectionSeam<CounterScreen>()
        try await Fleet.withHostedView(CounterScreen(seam: seam).environmentObject(model), window: host) { handle in
            try await inspectMounted(seam, in: handle.context) { try $0.vStack().button(2).tap() }
            XCTAssertEqual(model.taps, 1)
            try await handle.waitForUpdate("re-rendered text is inspectable") {
                currentTexts(seam) == ["tapped", "taps: 1"]
            }
            XCTAssertEqual(handle.lifecycle.count(of: .appeared), 1)
        }
    }

    func test_timeoutErrorAndCancellationPropagateAndReleaseTheRequest() async throws {
        let host = try XCTUnwrap(UIApplication.shared.keyWindow)
        let seam = InspectionSeam<CounterScreen>()
        let model = CounterModel()
        do {
            try await Fleet.withContext(window: host) { context in
                try await inspectMounted(seam, in: context, timeout: 0.1) { _ in 0 }
            }
            XCTFail("An unmounted screen must time out")
        } catch let failure as FleetFailure {
            XCTAssertEqual(failure.kind, .timedOut)
        }
        XCTAssertFalse(seam.hasPendingRequest)

        do {
            try await Fleet.withContext(window: host) { context in
                try await context.setRoot(UIHostingController(rootView: CounterScreen(seam: seam).environmentObject(model)))
                try await inspectMounted(seam, in: context) { try $0.vStack().text(7) }
            }
            XCTFail("An invalid inspection must throw")
        } catch is InspectionError {}
        XCTAssertFalse(seam.hasPendingRequest)

        // A fresh seam: a retained, no-longer-hosted controller would still answer the old one.
        let unmounted = InspectionSeam<CounterScreen>()
        let task = Task { @MainActor in
            try await Fleet.withContext(window: host) { context in
                try await inspectMounted(unmounted, in: context, timeout: 30) { _ in 0 }
            }
        }
        await Task.yield()
        task.cancel()
        do {
            try await task.value
            XCTFail("A cancelled inspection must throw")
        } catch is CancellationError {}
        XCTAssertFalse(unmounted.hasPendingRequest)
    }
}
