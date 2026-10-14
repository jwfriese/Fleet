import XCTest
@testable import Fleet

#if os(iOS)
    @testable import FleetTestApp
#elseif os(tvOS)
    @testable import FleetTestApp_tvOS
#endif

private final class TrackedController: UIViewController {}

@MainActor
private final class EventLog {
    var events: [String] = []
}

@MainActor
class FleetTestContextSpec: XCTestCase {
    private var hostWindow: UIWindow!
    private var scene: UIWindowScene!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        hostWindow = try XCTUnwrap(UIApplication.shared.keyWindow)
        scene = try XCTUnwrap(hostWindow.windowScene)
    }

    override func tearDown() async throws {
        hostWindow = nil
        scene = nil
        try await super.tearDown()
    }

    private func assertLeaseFree(file: StaticString = #filePath, line: UInt = #line) async throws {
        // A fresh scope can only start if the previous lease was released.
        let ran = try await Fleet.withContext(window: hostWindow) { _ in true }
        XCTAssertTrue(ran, file: file, line: line)
    }

    func test_overlappingContexts_excludeEachOtherThroughSetupBodyAndCleanup() async throws {
        let log = EventLog()
        var tasks: [Task<Void, Never>] = []
        do {
            for name in ["a", "b", "c"] {
                tasks.append(Task { @MainActor in
                    do {
                        try await Fleet.withContext(window: self.hostWindow) { context in
                            log.events.append("\(name):body-start")
                            try context.addCleanup { log.events.append("\(name):cleanup") }
                            try await Task.sleep(nanoseconds: 50_000_000)
                            log.events.append("\(name):body-end")
                        }
                        log.events.append("\(name):released")
                    } catch {
                        log.events.append("\(name):error")
                    }
                })
            }
        }
        for task in tasks { await task.value }
        XCTAssertEqual(log.events.count, 12)
        for chunk in stride(from: 0, to: log.events.count, by: 4) {
            let slice = log.events[chunk..<chunk + 4].map { $0.split(separator: ":").map(String.init) }
            let name = slice[0][0]
            XCTAssertEqual(slice.map { $0[0] }, [name, name, name, name], "Interleaved: \(log.events)")
            XCTAssertEqual(slice.map { $0[1] }, ["body-start", "body-end", "cleanup", "released"], "\(log.events)")
        }
    }

    func test_throwingBody_runsCleanupReleasesLeaseAndRestoresHost() async throws {
        struct Boom: Error {}
        let originalRoot = hostWindow.rootViewController
        var cleaned = false
        do {
            try await Fleet.withContext(window: hostWindow) { context in
                try context.addCleanup { cleaned = true }
                try await context.setRoot(UIViewController())
                throw Boom()
            }
            XCTFail("Expected the body's error")
        } catch is Boom {}
        XCTAssertTrue(cleaned)
        XCTAssertTrue(hostWindow.rootViewController === originalRoot)
        XCTAssertFalse(FleetContextCoordinator.shared.isHeld)
        try await assertLeaseFree()
    }

    func test_timedOutWait_throwsTypedFailureWithContextAndCleansUp() async throws {
        let originalRoot = hostWindow.rootViewController
        do {
            try await Fleet.withContext(window: hostWindow) { context in
                try await context.setRoot(UIViewController())
                try await context.waitUntil("a state that never occurs", timeout: 0.1) { false }
            }
            XCTFail("Expected a timeout")
        } catch let failure as FleetFailure {
            XCTAssertEqual(failure.kind, .timedOut)
            XCTAssertTrue(failure.action.contains("a state that never occurs"), failure.description)
            XCTAssertTrue(failure.state.contains("0.1"), failure.description)
            XCTAssertTrue(failure.state.contains("root=UIViewController"), failure.description)
        }
        XCTAssertTrue(hostWindow.rootViewController === originalRoot)
        try await assertLeaseFree()
    }

    func test_waitWithInvalidPollInterval_throwsInvalidInputAndCleansUp() async throws {
        let originalRoot = hostWindow.rootViewController
        for interval in [-0.01, 0, TimeInterval.nan, TimeInterval.infinity] {
            do {
                try await Fleet.withContext(window: hostWindow) { context in
                    try await context.setRoot(UIViewController())
                    try await context.waitUntil("state", pollInterval: interval) { false }
                }
                XCTFail("Expected invalid input for \(interval)")
            } catch let failure as FleetFailure {
                XCTAssertEqual(failure.kind, .invalidInput, failure.description)
                XCTAssertTrue(failure.state.contains("pollInterval"), failure.description)
            }
            XCTAssertTrue(hostWindow.rootViewController === originalRoot)
            XCTAssertFalse(FleetContextCoordinator.shared.isHeld)
        }
        try await assertLeaseFree()
    }

    func test_cancelledWhileRunning_cleansUpAndReleasesLease() async throws {
        let log = EventLog()
        let task = Task { @MainActor in
            try await Fleet.withContext(window: self.hostWindow) { context in
                try context.addCleanup { log.events.append("cleanup") }
                log.events.append("running")
                try await context.waitUntil("never", timeout: 30) { false }
            }
        }
        while log.events.isEmpty { await Task.yield() }
        task.cancel()
        do {
            try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        XCTAssertEqual(log.events, ["running", "cleanup"])
        try await assertLeaseFree()
    }

    func test_cancelledWhileAcquiring_doesNotLeakOrStealLease() async throws {
        let log = EventLog()
        let holder = Task { @MainActor in
            try await Fleet.withContext(window: self.hostWindow) { context in
                log.events.append("holder-running")
                try await context.waitUntil("release signal", timeout: 10) { log.events.contains("release") }
            }
        }
        while log.events.isEmpty { await Task.yield() }
        let waiter = Task { @MainActor in
            try await Fleet.withContext(window: self.hostWindow) { _ in log.events.append("waiter-ran") }
        }
        while FleetContextCoordinator.shared.waiterCount == 0 { await Task.yield() }
        waiter.cancel()
        do {
            try await waiter.value
            XCTFail("Expected cancellation while acquiring")
        } catch is CancellationError {}
        XCTAssertEqual(FleetContextCoordinator.shared.waiterCount, 0)
        log.events.append("release")
        try await holder.value
        XCTAssertFalse(log.events.contains("waiter-ran"))
        XCTAssertFalse(FleetContextCoordinator.shared.isHeld)
        try await assertLeaseFree()
    }

    func test_borrowedWindow_restoresRootAndKeyState() async throws {
        let originalRoot = hostWindow.rootViewController
        let tracked = TrackedController()
        try await Fleet.withContext(window: hostWindow) { context in
            try await context.setRoot(tracked)
            XCTAssertTrue(context.screen.topmostViewController === tracked)
            XCTAssertTrue(context.window.isKeyWindow)
        }
        XCTAssertTrue(hostWindow.rootViewController === originalRoot)
        XCTAssertTrue(hostWindow.isKeyWindow)
        XCTAssertFalse(hostWindow.isHidden)
    }

    func test_ownedSceneWindow_isDismantledAndControllersDeallocate() async throws {
        weak var weakController: TrackedController?
        weak var weakWindow: UIWindow?
        try await Fleet.withContext(scene: scene) { context in
            XCTAssertTrue(context.ownsWindow)
            XCTAssertTrue(context.window.windowScene === self.scene)
            XCTAssertTrue(context.window.isKeyWindow)
            let controller = TrackedController()
            weakController = controller
            weakWindow = context.window
            try await context.setRoot(controller)
            XCTAssertTrue(context.screen.topmostViewController === controller)
        }
        for _ in 0..<50 where weakController != nil || weakWindow != nil {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertNil(weakController, "Owned controller leaked")
        XCTAssertNil(weakWindow, "Owned window leaked")
        XCTAssertTrue(hostWindow.isKeyWindow)
    }

    func test_presentedControllerIsDismissedDuringCleanup() async throws {
        let originalRoot = hostWindow.rootViewController
        let root = UIViewController()
        try await Fleet.withContext(window: hostWindow) { context in
            try await context.setRoot(root)
            root.present(UIViewController(), animated: false)
            try await context.waitUntil("presentation") { root.presentedViewController != nil }
            try await context.waitForTransitionsToFinish()
        }
        XCTAssertNil(root.presentedViewController)
        XCTAssertTrue(hostWindow.rootViewController === originalRoot)
    }

    func test_contextUsedAfterScope_throwsContextEnded() async throws {
        var escaped: FleetTestContext?
        try await Fleet.withContext(window: hostWindow) { escaped = $0 }
        do {
            try escaped?.addCleanup {}
            XCTFail("Expected contextEnded")
        } catch let failure as FleetFailure {
            XCTAssertEqual(failure.kind, .invalidSetup)
        }
    }

    func test_borrowedWindow_restoresVisibilityAndKeyStatusAfterBodyChangesThem() async throws {
        let other = UIWindow(windowScene: scene)
        defer { other.isHidden = true }
        try await Fleet.withContext(window: hostWindow) { context in
            other.makeKeyAndVisible()
            context.window.isHidden = true
        }
        XCTAssertFalse(hostWindow.isHidden)
        XCTAssertTrue(hostWindow.isKeyWindow)
    }

    func test_cancelledQueuedContext_neverRunsBodyDuringHandoff() async throws {
        let log = EventLog()
        var waiter: Task<Void, Error>?
        try await Fleet.withContext(window: hostWindow) { _ in
            waiter = Task { @MainActor in
                try await Fleet.withContext(window: self.hostWindow) { _ in log.events.append("waiter-ran") }
            }
            while FleetContextCoordinator.shared.waiterCount == 0 { await Task.yield() }
            waiter?.cancel()
        }
        do {
            try await waiter?.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {}
        XCTAssertFalse(log.events.contains("waiter-ran"))
        try await assertLeaseFree()
    }
}
