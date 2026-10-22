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

private struct HostError: Error {}

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
            host.layoutIfNeeded()
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
                host.layoutIfNeeded()
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
}
