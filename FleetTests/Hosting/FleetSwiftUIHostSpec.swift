import SwiftUI
import XCTest
@testable import Fleet

#if os(iOS)
    @testable import FleetTestApp
#elseif os(tvOS)
    @testable import FleetTestApp_tvOS
#endif

@MainActor
private final class HostedModel: ObservableObject {
    @Published var count = 0
    var loads = 0
}

@MainActor
private final class FakeWork {
    var started = 0
    var cancelled = 0
    /// Suspends until cancelled, like a fake stream the application owns.
    func run() async {
        started += 1
        while !Task.isCancelled { try? await Task.sleep(nanoseconds: 5_000_000) }
        cancelled += 1
    }
}

private struct HostedScreen: View {
    @EnvironmentObject var model: HostedModel
    let work: FakeWork
    let taskID: Int

    var body: some View {
        VStack {
            Text("count: \(model.count)")
            Button("Add") { model.count += 1 }
        }
        .fleetObservedTask("load", id: taskID) { await work.run() }
    }
}

private struct SheetScreen: View {
    @ObservedObject var model: HostedModel
    var body: some View {
        Text("root")
            .sheet(isPresented: Binding(get: { model.count > 0 }, set: { _ in })) {
                Text("sheet content").onAppear { model.loads += 1 }
            }
    }
}

private struct DisappearScreen: View {
    let model: HostedModel
    var body: some View {
        Text("bye").onDisappear { model.loads += 1 }
    }
}

private final class SlowCleanup {
    var finished = false
}

private struct SlowCleanupScreen: View {
    let cleanup: SlowCleanup
    var body: some View {
        Text("slow").fleetObservedTask("slow") {
            while !Task.isCancelled { try? await Task.sleep(nanoseconds: 5_000_000) }
            // Acknowledges cancellation, then takes longer than the teardown bound to finish.
            await Task { try? await Task.sleep(nanoseconds: 3_000_000_000) }.value
            cleanup.finished = true
        }
    }
}

private struct HostError: Error {}

private struct NativeButton: UIViewRepresentable {
    let title: String
    let action: @MainActor () -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.accessibilityLabel = title
        button.addAction(UIAction { _ in MainActor.assumeIsolated { self.action() } }, for: .touchUpInside)
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {}
}

private struct NativeLabel: UIViewRepresentable {
    let text: String
    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.text = text
        return label
    }
    func updateUIView(_ label: UILabel, context: Context) { label.text = text }
}

/// A small edit/delete screen: items are listed, "Edit" reveals "Delete", which removes an item.
private struct ItemsScreen: View {
    @ObservedObject var model: HostedModel
    var body: some View {
        VStack {
            NativeLabel(text: "items: \(model.count)")
            NativeButton(title: "Edit") { model.loads = 1 }
            NativeButton(title: "Delete") { model.count -= 1 }.disabled(model.count == 0)
            NativeButton(title: "Archive") {}
            NativeButton(title: "Archive") {}
        }
    }
}

@MainActor
class FleetSwiftUIHostSpec: XCTestCase {
    private var hostWindow: UIWindow!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        hostWindow = try XCTUnwrap(UIApplication.shared.keyWindow)
    }

    override func tearDown() async throws {
        hostWindow = nil
        try await super.tearDown()
    }

    func test_hostedScreen_keepsInjectedModelAcrossUpdates_andReportsDistinctEvents() async throws {
        let model = HostedModel()
        let work = FakeWork()
        var escaped: FleetHostedView?
        try await Fleet.withHostedView(HostedScreen(work: work, taskID: 1).environmentObject(model), window: hostWindow) { host in
            escaped = host
            XCTAssertTrue(host.isReady)
            XCTAssertEqual(host.lifecycle.count(of: .appeared), 1)
            XCTAssertTrue(host.hostingController.view.window === self.hostWindow)
            try await host.waitForTaskStart("load")
            model.count += 1
            try await host.waitForUpdate("model update visible") { model.count == 1 }
            XCTAssertEqual(host.lifecycle.count(of: .appeared), 1, "update does not remount")
            XCTAssertEqual(host.lifecycle.count(of: .disappeared), 0)
            XCTAssertEqual(work.cancelled, 0)
            try await host.remove()
            XCTAssertEqual(host.lifecycle.count(of: .disappeared), 1)
            try await host.waitForTaskCancellation("load")
            XCTAssertEqual(work.cancelled, 1)
        }
        XCTAssertTrue(hostWindow.rootViewController !== escaped?.hostingController)
        do {
            try await escaped?.waitForAppearance(timeout: 0.1)
            XCTFail("handle outlived its scope")
        } catch let failure as FleetFailure {
            XCTAssertEqual(failure.kind, .invalidSetup)
        }
    }

    func test_taskWithChangedID_isCancelledAndRestarted() async throws {
        struct Wrapper: View {
            @ObservedObject var model: HostedModel
            let work: FakeWork
            var body: some View { Color.clear.fleetObservedTask("load", id: model.count) { await work.run() } }
        }
        let model = HostedModel()
        let work = FakeWork()
        try await Fleet.withHostedView(Wrapper(model: model, work: work), window: hostWindow) { host in
            try await host.waitForTaskStart("load")
            model.count = 1
            try await host.waitForTaskCancellation("load")
            try await host.waitForTaskStart("load", count: 2)
            XCTAssertEqual(work.started, 2)
        }
        XCTAssertEqual(work.cancelled, 2, "scope end released the outstanding fake work")
    }

    func test_thrownError_dismantlesHostAndReleasesWork() async throws {
        let work = FakeWork()
        do {
            try await Fleet.withHostedView(HostedScreen(work: work, taskID: 1).environmentObject(HostedModel()), window: hostWindow) { host in
                try await host.waitForTaskStart("load")
                throw HostError()
            }
            XCTFail("expected throw")
        } catch is HostError {}
        XCTAssertEqual(work.cancelled, 1)
        let next = try await Fleet.withContext(window: hostWindow) { $0.window.rootViewController }
        XCTAssertFalse(next is UIHostingController<AnyView>)
    }

    func test_failedWait_throwsTypedTimeoutWithEnvironment_andCleansUp() async throws {
        let work = FakeWork()
        do {
            try await Fleet.withHostedView(HostedScreen(work: work, taskID: 1).environmentObject(HostedModel()), window: hostWindow) { host in
                try await host.waitForUpdate("never", timeout: 0.1) { false }
            }
            XCTFail("expected timeout")
        } catch let failure as FleetFailure {
            XCTAssertEqual(failure.kind, .timedOut)
            XCTAssertTrue(failure.state.contains("Resolved environment"))
        }
        XCTAssertEqual(work.cancelled, 1)
    }

    func test_cancellation_stillDismantles() async throws {
        let work = FakeWork()
        let task = Task { @MainActor in
            try await Fleet.withHostedView(HostedScreen(work: work, taskID: 1).environmentObject(HostedModel()), window: self.hostWindow) { host in
                try await host.waitForTaskStart("load")
                try await Task.sleep(nanoseconds: 10_000_000_000)
            }
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        task.cancel()
        do { try await task.value; XCTFail("expected cancellation") } catch is CancellationError {}
        XCTAssertEqual(work.cancelled, 1)
    }

    func test_mount_doesNotForceAppearanceOrWait_andCallerSequencesExplicitly() async throws {
        try await Fleet.withContext(window: hostWindow) { context in
            let host = try context.mount(Text("low level"))
            XCTAssertEqual(host.lifecycle.count(of: .appeared), 0, "mount does not wait for or force appearance")
            try host.layoutIfNeeded()
            try await host.waitUntilMounted()
            try await host.waitUntilReady()
            try await host.waitForAppearance()
            XCTAssertFalse(host.isRemoved)
        }
    }

    func test_sheet_liveContentAppears() async throws {
        let model = HostedModel()
        try await Fleet.withHostedView(SheetScreen(model: model), window: hostWindow) { host in
            model.count = 1  // drives SwiftUI's real .sheet presentation
            try await host.waitForUpdate("sheet content on screen") {
                model.loads == 1 && host.hostingController.presentedViewController?.view.window === self.hostWindow
            }
        }
    }

    func test_contextHost_drainsObservedWorkBeforeScopeReturns() async throws {
        let work = FakeWork()
        try await Fleet.withContext(window: hostWindow) { context in
            let host = try await context.host(HostedScreen(work: work, taskID: 1).environmentObject(HostedModel()))
            try await host.waitForTaskStart("load")
        }
        XCTAssertEqual(work.cancelled, 1, "context.host handles drain observed work before the lease is released")
    }

    func test_contextMount_drainsObservedWorkOnThrow() async throws {
        let work = FakeWork()
        do {
            try await Fleet.withContext(window: hostWindow) { context in
                let host = try context.mount(HostedScreen(work: work, taskID: 1).environmentObject(HostedModel()))
                try host.layoutIfNeeded()
                try await host.waitForTaskStart("load")
                throw HostError()
            }
            XCTFail("expected throw")
        } catch is HostError {}
        XCTAssertEqual(work.cancelled, 1)
    }

    func test_taskFreeScope_deliversDisappearanceBeforeReturning() async throws {
        let model = HostedModel()
        try await Fleet.withHostedView(DisappearScreen(model: model), window: hostWindow) { _ in }
        XCTAssertEqual(model.loads, 1, "application onDisappear ran inside the scope that hosted it")
    }

    func test_failures_carryCallerSource() async throws {
        let model = HostedModel()
        var escaped: FleetHostedView?
        let timeoutLine = #line + 4
        do {
            try await Fleet.withHostedView(DisappearScreen(model: model), window: hostWindow) { host in
                escaped = host
                try await host.waitForUpdate("never", timeout: 0.05) { false }
            }
            XCTFail("expected timeout")
        } catch let failure as FleetFailure {
            XCTAssertEqual(failure.source?.line, UInt(timeoutLine))
            XCTAssertTrue(failure.source?.fileID.hasSuffix("FleetSwiftUIHostSpec.swift") ?? false)
            XCTAssertTrue(failure.description.contains("called at"))
        }
        let endedLine = #line + 2
        do {
            try await escaped?.waitForAppearance(timeout: 0.05)
            XCTFail("expected invalid scope")
        } catch let failure as FleetFailure {
            XCTAssertEqual(failure.kind, .invalidSetup)
            XCTAssertEqual(failure.source?.line, UInt(endedLine))
        }
    }

    func test_immediateMount_cannotStartObservedWorkAfterScope() async throws {
        let work = FakeWork()
        let model = HostedModel()
        try await Fleet.withContext(window: hostWindow) { context in
            _ = try context.mount(HostedScreen(work: work, taskID: 0).environmentObject(model))
        }
        try await Fleet.withContext(window: hostWindow) { context in
            try? await context.waitUntil("run-loop turns to pass", timeout: 0.3) { false }
        }
        XCTAssertEqual(work.started, 0, "work must not start after its scope ended")
    }

    func test_immediateMount_doesNotDeliverAppearanceInNextScope() async throws {
        let model = HostedModel()
        var appearances = 0
        try await Fleet.withContext(window: hostWindow) { context in
            _ = try context.mount(Text("immediate").onAppear { appearances += 1 }.environmentObject(model))
        }
        let atReturn = appearances
        try await Fleet.withContext(window: hostWindow) { context in
            try? await context.waitUntil("run-loop turns to pass", timeout: 0.3) { false }
        }
        XCTAssertEqual(appearances, atReturn, "previous screen's onAppear must not run in a later scope")
    }

    func test_immediateExplicitRemoval_doesNotDeliverAppearanceInNextScope() async throws {
        var appearances = 0
        try await Fleet.withContext(window: hostWindow) { context in
            let host = try context.mount(Text("removed at once").onAppear { appearances += 1 })
            try await host.remove()
        }
        let atReturn = appearances
        try await Fleet.withContext(window: hostWindow) { context in
            try? await context.waitUntil("run-loop turns to pass", timeout: 0.3) { false }
        }
        XCTAssertEqual(appearances, atReturn, "removed screen's onAppear must not run in a later scope")
    }

    func test_immediateRemove_deliversAppearAndDisappearBeforeReturning() async throws {
        var events: [String] = []
        try await Fleet.withContext(window: hostWindow) { context in
            let host = try context.mount(Text("removed at once")
                .onAppear { events.append("appeared") }
                .onDisappear { events.append("disappeared") })
            try await host.remove()
            XCTAssertEqual(events, ["appeared", "disappeared"])
        }
    }

    func test_escapedHandle_layoutIfNeeded_throwsInvalidSetup() async throws {
        var escaped: FleetHostedView?
        try await Fleet.withHostedView(Text("scoped"), window: hostWindow) { escaped = $0 }
        do {
            try escaped?.layoutIfNeeded()
            XCTFail("expected invalidSetup")
        } catch let failure as FleetFailure {
            XCTAssertEqual(failure.kind, .invalidSetup)
            XCTAssertNotNil(failure.source)
        }
    }

    func test_teardownDeadline_reportsTypedTimeout() async throws {
        let cleanup = SlowCleanup()
        do {
            try await Fleet.withHostedView(SlowCleanupScreen(cleanup: cleanup), window: hostWindow) { handle in
                try await handle.waitForTaskStart("slow")
            }
            XCTFail("expected a cleanup timeout")
        } catch let failure as FleetFailure {
            XCTAssertEqual(failure.kind, .timedOut)
            XCTAssertEqual(failure.action, "tear down hosted view")
            XCTAssertNotNil(failure.source)
        }
        XCTAssertFalse(cleanup.finished)
        // Let the slow fake finish so it cannot affect the next test.
        try await Fleet.withContext(window: hostWindow) { context in
            try await context.waitUntil("slow cleanup to finish", timeout: 5) { cleanup.finished }
        }
    }

    // MARK: Failure diagnostics

    private func failure(_ body: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async -> FleetFailure? {
        do { try await body() } catch let failure as FleetFailure { return failure } catch { XCTFail("unexpected \(error)", file: file, line: line) }
        XCTFail("expected a FleetFailure", file: file, line: line)
        return nil
    }

    func test_tap_rejectsHiddenAndNoninteractiveButtonsWithoutInvokingThem() async throws {
        let model = HostedModel()
        try await Fleet.withHostedView(ItemsScreen(model: model), window: hostWindow) { host in
            try await host.waitForUpdate("buttons present") { !host.matchingViews(label: "Edit", identifier: nil).isEmpty }
            let edit = try XCTUnwrap(host.matchingViews(label: "Edit", identifier: nil).first as? UIButton)
            for disable in [{ edit.isUserInteractionEnabled = false }, { edit.isUserInteractionEnabled = true; edit.isHidden = true }] {
                disable()
                do {
                    try host.tap(label: "Edit")
                    XCTFail("expected an unavailable-interaction failure")
                } catch let failure as FleetFailure {
                    XCTAssertEqual(failure.kind, .unavailableInteraction)
                    XCTAssertNotNil(failure.diagnostics)
                }
            }
            XCTAssertEqual(model.loads, 0)
        }
    }

    func test_queryFailures_areDistinguishableAndCarryDiagnostics() async throws {
        let model = HostedModel()
        try await Fleet.withHostedView(ItemsScreen(model: model), window: hostWindow) { host in
            try await host.waitForUpdate("buttons present") { !host.matchingViews(label: "Edit", identifier: nil).isEmpty }
            @MainActor func tapFailure(_ label: String) -> FleetFailure? {
                do { try host.tap(label: label) } catch let failure as FleetFailure { return failure } catch {}
                return nil
            }
            let missing = try XCTUnwrap(tapFailure("Nope"))
            XCTAssertEqual(missing.kind, .notFound)
            XCTAssertEqual(missing.diagnostics?.matchCount, 0)

            let ambiguous = try XCTUnwrap(tapFailure("Archive"))
            XCTAssertEqual(ambiguous.kind, .ambiguous)
            XCTAssertEqual(ambiguous.diagnostics?.matchCount, 2)
            XCTAssertEqual(ambiguous.diagnostics?.candidates.count, 2)

            let disabled = try XCTUnwrap(tapFailure("Delete"))
            XCTAssertEqual(disabled.kind, .unavailableInteraction)

            let unsupported = try XCTUnwrap(tapFailure("items: 0"))
            XCTAssertEqual(unsupported.kind, .unsupported)

            let diagnostics = try XCTUnwrap(disabled.diagnostics)
            XCTAssertEqual(diagnostics.lastAction, "tap label == \"Delete\"")
            XCTAssertEqual(diagnostics.query, "label == \"Delete\"")
            XCTAssertTrue(diagnostics.hierarchy.contains("UIButton label=\"Delete\" enabled=false"), diagnostics.hierarchy)
            XCTAssertTrue(diagnostics.environment.contains("Resolved environment"))
            XCTAssertTrue(diagnostics.lifecycle.contains("mounted=true"))
            if case .captured(let png) = diagnostics.screenshot { XCTAssertFalse(png.isEmpty) } else { XCTFail("expected a screenshot: \(diagnostics.screenshot)") }
            XCTAssertEqual(diagnostics.attachments.map(\.uniformTypeIdentifier), ["public.plain-text", "public.png"])
            XCTAssertTrue(disabled.detailedDescription.contains("Last action"))
        }
    }

    func test_timeout_pointsAtCallingTestAndCarriesLastAction() async throws {
        let model = HostedModel()
        var expectedLine: UInt = 0
        let caught = await failure {
            try await Fleet.withHostedView(ItemsScreen(model: model), window: self.hostWindow) { host in
                host.recordAction("press save")
                expectedLine = #line + 1
                try await host.waitForUpdate("never", timeout: 0.1) { false }
            }
        }
        let timeout = try XCTUnwrap(caught)
        XCTAssertEqual(timeout.kind, .timedOut)
        XCTAssertEqual(timeout.source?.line, expectedLine)
        XCTAssertEqual(timeout.diagnostics?.lastAction, "press save")
        XCTAssertFalse(timeout.diagnostics?.hierarchy.isEmpty ?? true)
    }

    func test_contentWaitTimeouts_carryDiagnostics() async throws {
        let model = HostedModel()
        var failures: [FleetFailure] = []
        try await Fleet.withHostedView(ItemsScreen(model: model), window: hostWindow) { host in
            host.recordAction("open detail")
            for wait in [
                { try await host.waitForContentPresented("missing", timeout: 0.1) },
                { try await host.waitForContent("missing", values: ["a": "b"], timeout: 0.1) }
            ] as [() async throws -> Void] {
                do { try await wait() } catch let failure as FleetFailure { failures.append(failure) }
            }
        }
        XCTAssertEqual(failures.count, 2)
        for failure in failures {
            XCTAssertEqual(failure.kind, .timedOut)
            XCTAssertEqual(failure.diagnostics?.lastAction, "open detail")
        }
    }

    func test_unavailableScreenshot_isReportedExplicitly() async throws {
        var escaped: FleetHostedView?
        try await Fleet.withHostedView(Text("x"), window: hostWindow) { escaped = $0 }
        let diagnostics = try XCTUnwrap(escaped).diagnostics()
        XCTAssertEqual(diagnostics.screenshot, .unavailable(reason: "the hosting scope has ended"))
        XCTAssertTrue(diagnostics.report.contains("Screenshot: unavailable"))
    }

    func test_tracing_isOptInBounded_andShowsEditDeleteScenario() async throws {
        let model = HostedModel()
        model.count = 1
        var untraced: FleetHostedView?
        try await Fleet.withHostedView(ItemsScreen(model: model), window: hostWindow) { host in
            untraced = host
            XCTAssertNil(host.trace)
            try host.tap(label: "Edit")
        }
        XCTAssertNil(untraced?.diagnostics().trace.first, "tracing stays off unless enabled")

        model.count = 1
        let caught = await failure {
            try await Fleet.withHostedView(ItemsScreen(model: model), window: self.hostWindow) { host in
                host.enableTracing(limit: 4)
                try host.tap(label: "Edit")
                try host.tap(label: "Delete")
                try await host.waitForUpdate("item removed and Delete disabled", timeout: 2) {
                    model.count == 0 && (host.matchingViews(label: "Delete", identifier: nil).first as? UIControl)?.isEnabled == false
                }
                try host.tap(label: "Delete")  // now disabled: the scenario's failure
            }
        }
        let diagnostics = try XCTUnwrap(caught?.diagnostics)
        XCTAssertEqual(caught?.kind, .unavailableInteraction)
        XCTAssertEqual(diagnostics.trace.count, 4, "bounded to the limit")
        XCTAssertGreaterThan(diagnostics.traceDroppedCount, 0)
        XCTAssertEqual(diagnostics.trace.last, "action: tap label == \"Delete\"")
        XCTAssertTrue(diagnostics.trace.contains("performed tap label == \"Delete\""))
    }
}
