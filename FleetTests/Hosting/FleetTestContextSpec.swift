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

    func test_waitWithNonFiniteTimeout_throwsInvalidInputAndCleansUp() async throws {
        let originalRoot = hostWindow.rootViewController
        for timeout in [TimeInterval.nan, TimeInterval.infinity, -TimeInterval.infinity] {
            do {
                try await Fleet.withContext(window: hostWindow) { context in
                    try await context.setRoot(UIViewController())
                    try await context.waitUntil("state", timeout: timeout) { false }
                }
                XCTFail("Expected invalid input for \(timeout)")
            } catch let failure as FleetFailure {
                XCTAssertEqual(failure.kind, .invalidInput, failure.description)
                XCTAssertTrue(failure.state.contains("timeout"), failure.description)
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
            let window = self.hostWindow!
            waiter = detachedTask {
                try await Fleet.withContext(window: window) { _ in log.events.append("waiter-ran") }
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

    func test_queuedSceneContext_doesNotCreateWindowUntilLeaseIsHeld() async throws {
        var waiter: Task<Void, Error>?
        try await Fleet.withContext(window: hostWindow) { _ in
            let before = self.scene.windows.map { ObjectIdentifier($0) }
            let scene = self.scene!
            waiter = detachedTask {
                try await Fleet.withContext(scene: scene) { _ in }
            }
            while FleetContextCoordinator.shared.waiterCount == 0 { await Task.yield() }
            XCTAssertEqual(self.scene.windows.map { ObjectIdentifier($0) }, before)
        }
        try await waiter?.value
        try await assertLeaseFree()
    }

    // MARK: Nested acquisition

    /// An independent caller. A plain `Task` started inside a scope inherits its task-local
    /// context and would count as nested; clearing the task-local models a detached task, which does not.
    private func detachedTask(_ operation: @escaping @MainActor @Sendable () async throws -> Void) -> Task<Void, Error> {
        Task { @MainActor in
            try await FleetTestContext.$current.withValue(nil) { try await operation() }
        }
    }

    /// Awaits `task`, cancelling it after `seconds` so a regression that waits on a lease fails
    /// promptly (as a cancellation) instead of hitting the XCTest timeout.
    private func awaiting<T: Sendable>(_ task: Task<T, Error>, within seconds: Double = 2) async throws -> T {
        let watchdog = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            task.cancel()
        }
        defer { watchdog.cancel() }
        return try await task.value
    }

    private func bounded<T: Sendable>(_ operation: @escaping @MainActor () async throws -> T) async throws -> T {
        try await awaiting(Task { @MainActor in try await operation() })
    }

    private func waitForQueuedCaller() async throws {
        while FleetContextCoordinator.shared.waiterCount == 0 {
            try Task.checkCancellation()
            await Task.yield()
        }
    }

    /// Runs `operation` in a child task that inherits the task-local context, with its own watchdog.
    private func inheritedFailure(_ operation: @escaping @MainActor () async throws -> Void) async -> Error? {
        do {
            _ = try await awaiting(Task { @MainActor in try await operation() })
            return nil
        } catch {
            return error
        }
    }

    private func directFailure(_ operation: @MainActor () async throws -> Void) async -> Error? {
        do {
            try await operation()
            return nil
        } catch {
            return error
        }
    }

    private func assertNestedRejected(_ error: Error?, file: StaticString = #filePath, line: UInt = #line) {
        let failure = error as? FleetFailure
        XCTAssertEqual(failure?.kind, .invalidSetup, "Got \(String(describing: error))", file: file, line: line)
    }

    private enum Overload { case window, scene }

    @MainActor
    private final class NestedOutcome {
        var error: Error?
        var queued: Task<Void, Error>?
    }

    private func attempt(_ overload: Overload) async throws {
        switch overload {
        case .window: try await Fleet.withContext(window: hostWindow) { _ in XCTFail("Nested body ran") }
        case .scene: try await Fleet.withContext(scene: scene) { _ in XCTFail("Nested body ran") }
        }
    }

    private func enclose(_ overload: Overload, _ body: @escaping @MainActor (FleetTestContext) async throws -> Void) async throws {
        switch overload {
        case .window: try await Fleet.withContext(window: hostWindow, body)
        case .scene: try await Fleet.withContext(scene: scene, body)
        }
    }

    /// Nests `inner` inside `outer`, directly in the enclosing task or from an awaited child task,
    /// then checks rejection, an untouched UI, and that a queued caller and a successor still run.
    private func runNestedScenario(outer: Overload, inner: Overload, inherited: Bool) async throws {
        let outcome = NestedOutcome()
        let window: UIWindow = hostWindow
        try await bounded {
            try await self.enclose(outer) { context in
                let marker = UIViewController()
                try await context.setRoot(marker)
                let windowsBefore = self.scene.windows.map { ObjectIdentifier($0) }
                let nested: @MainActor () async throws -> Void = { try await self.attempt(inner) }
                outcome.error = inherited ? await self.inheritedFailure(nested) : await self.directFailure(nested)
                XCTAssertEqual(FleetContextCoordinator.shared.waiterCount, 0)
                XCTAssertTrue(context.isActive)
                XCTAssertTrue(context.window.rootViewController === marker)
                XCTAssertEqual(self.scene.windows.map { ObjectIdentifier($0) }, windowsBefore)
                outcome.queued = self.detachedTask { try await Fleet.withContext(window: window) { _ in } }
                try await self.waitForQueuedCaller()
            }
        }
        assertNestedRejected(outcome.error)
        if let queued = outcome.queued { try await awaiting(queued) }
        try await bounded { try await self.assertLeaseFree() }
    }

    func test_nestedWindowInWindow_isRejectedWithoutWaiting() async throws {
        try await runNestedScenario(outer: .window, inner: .window, inherited: false)
        try await runNestedScenario(outer: .window, inner: .window, inherited: true)
    }

    func test_nestedSceneInWindow_isRejectedWithoutCreatingWindow() async throws {
        try await runNestedScenario(outer: .window, inner: .scene, inherited: false)
        try await runNestedScenario(outer: .window, inner: .scene, inherited: true)
    }

    func test_nestedWindowInScene_isRejected() async throws {
        try await runNestedScenario(outer: .scene, inner: .window, inherited: false)
        try await runNestedScenario(outer: .scene, inner: .window, inherited: true)
    }

    func test_nestedSceneInScene_isRejected() async throws {
        try await runNestedScenario(outer: .scene, inner: .scene, inherited: false)
        try await runNestedScenario(outer: .scene, inner: .scene, inherited: true)
    }

    func test_nestedFailure_propagatesOuterBodyErrorAndCleansUp() async throws {
        struct Boom: Error {}
        let outcome = NestedOutcome()
        let cleaned = EventLog()
        do {
            try await bounded {
                try await Fleet.withContext(window: self.hostWindow) { outer in
                    try outer.addCleanup { cleaned.events.append("cleanup") }
                    outcome.error = await self.directFailure { try await self.attempt(.window) }
                    throw Boom()
                }
            }
            XCTFail("Expected Boom")
        } catch is Boom {}
        assertNestedRejected(outcome.error)
        XCTAssertEqual(cleaned.events, ["cleanup"])
        try await bounded { try await self.assertLeaseFree() }
    }
}
