import SwiftUI
import UIKit

/// One observed lifecycle fact about a hosted SwiftUI screen. Each case is a distinct event:
/// appearance, update, disappearance and task start/cancellation are never conflated.
public enum FleetLifecycleEvent: Sendable, Equatable {
    /// SwiftUI delivered `onAppear` for the hosted root.
    case appeared
    /// SwiftUI delivered `onDisappear` for the hosted root.
    case disappeared
    /// A task observed with `fleetObservedTask` started running.
    case taskStarted(name: String)
    /// A task observed with `fleetObservedTask` was cooperatively cancelled (by removal or an `id` change).
    case taskCancelled(name: String)
    /// A task observed with `fleetObservedTask` returned without being cancelled.
    case taskFinished(name: String)
}

/// Records events from the SwiftUI runtime. Events come only from real mounting, removal and
/// identity changes; nothing here invokes an application callback.
@MainActor
public final class FleetLifecycleRecorder {
    public private(set) var events: [FleetLifecycleEvent] = []
    /// Number of times the hosted content has been told to refresh since mounting.
    public private(set) var updateCount = 0

    public init() {}

    func record(_ event: FleetLifecycleEvent) { events.append(event) }
    func recordUpdate() { updateCount += 1 }

    public func count(of event: FleetLifecycleEvent) -> Int { events.filter { $0 == event }.count }
    public var isAppeared: Bool { count(of: .appeared) > count(of: .disappeared) }
}

private struct FleetLifecycleRecorderKey: EnvironmentKey {
    static let defaultValue: FleetLifecycleRecorder? = nil
}

extension EnvironmentValues {
    /// The recorder of the enclosing Fleet host, if any.
    var fleetLifecycleRecorder: FleetLifecycleRecorder? {
        get { self[FleetLifecycleRecorderKey.self] }
        set { self[FleetLifecycleRecorderKey.self] = newValue }
    }
}

private struct FleetObservedTask<ID: Equatable & Sendable>: ViewModifier {
    @Environment(\.fleetLifecycleRecorder) private var recorder
    let name: String
    let id: ID
    let action: @MainActor @Sendable () async -> Void

    func body(content: Content) -> some View {
        content.task(id: id) { @MainActor in
            recorder?.record(.taskStarted(name: name))
            await action()
            recorder?.record(Task.isCancelled ? .taskCancelled(name: name) : .taskFinished(name: name))
        }
    }
}

extension View {
    /// `.task(id:)` that reports start and cooperative cancellation to the enclosing Fleet host.
    /// Outside a Fleet host it behaves exactly like `.task(id:)`. Only tasks started through this
    /// modifier are observed; Fleet cannot cancel or see arbitrary `Task`s your code creates, and
    /// cancellation is observed only once `action` returns (it must cooperate with cancellation).
    public func fleetObservedTask<ID: Equatable & Sendable>(
        _ name: String,
        id: ID,
        _ action: @escaping @MainActor @Sendable () async -> Void
    ) -> some View {
        modifier(FleetObservedTask(name: name, id: id, action: action))
    }

    /// `.task` that reports start and cooperative cancellation to the enclosing Fleet host.
    public func fleetObservedTask(
        _ name: String,
        _ action: @escaping @MainActor @Sendable () async -> Void
    ) -> some View {
        modifier(FleetObservedTask(name: name, id: 0, action: action))
    }
}

private struct FleetProbeRoot: View {
    let recorder: FleetLifecycleRecorder
    let content: AnyView

    var body: some View {
        content
            .environment(\.fleetLifecycleRecorder, recorder)
            .onAppear { recorder.record(.appeared) }
            .onDisappear { recorder.record(.disappeared) }
    }
}

/// Runs `body`, attributing any `FleetFailure` it throws to the caller's source location.
@MainActor
func fleetAttributing<T>(
    _ fileID: String,
    _ line: UInt,
    _ body: @MainActor () async throws -> T
) async throws -> T {
    do {
        return try await body()
    } catch let failure as FleetFailure {
        throw failure.attributed(to: FleetSourceLocation(fileID: fileID, line: line))
    }
}

/// A scoped handle to one SwiftUI screen mounted by Fleet in a context's window.
///
/// The handle is valid only inside the `withHostedView` / `FleetTestContext.mount` scope that
/// produced it; after the scope ends every operation throws `FleetFailure(.invalidSetup)`.
@MainActor
public final class FleetHostedView {
    public let context: FleetTestContext
    /// The single hosting controller for this screen. It is the window's root until removal.
    public let hostingController: UIHostingController<AnyView>
    public let lifecycle: FleetLifecycleRecorder
    private(set) var isRemoved = false

    init(context: FleetTestContext, hostingController: UIHostingController<AnyView>, lifecycle: FleetLifecycleRecorder) {
        self.context = context
        self.hostingController = hostingController
        self.lifecycle = lifecycle
    }

    private func requireActive(_ action: String) throws {
        guard context.isActive else {
            throw FleetFailure(
                kind: .invalidSetup,
                action: action,
                target: "FleetHostedView",
                state: "its hosting scope has already ended",
                reason: "Use the handle only inside the scope that produced it."
            )
        }
    }

    /// Mounted: the hosting view is in the context window.
    public var isMounted: Bool {
        !isRemoved && hostingController.isViewLoaded && hostingController.view.window === context.window
    }

    /// Ready: mounted with a positive-size laid-out hosting view. Does not imply `appeared`.
    public var isReady: Bool {
        guard isMounted else { return false }
        let size = hostingController.view.bounds.size
        return size.width > 0 && size.height > 0
    }

    /// Lower-level step: runs a layout pass on the window. Never called implicitly by `mount`.
    public func layoutIfNeeded() {
        context.window.layoutIfNeeded()
    }

    /// Waits (bounded) until the hosting view is in the window.
    public func waitUntilMounted(timeout: TimeInterval = 5, fileID: String = #fileID, line: UInt = #line) async throws {
        try await fleetAttributing(fileID, line) {
            try requireActive("wait for hosted view to mount")
            try await context.waitUntil("hosted SwiftUI view to be mounted", timeout: timeout) { self.isMounted }
        }
    }

    /// Waits (bounded) until the hosting view is mounted with positive size.
    public func waitUntilReady(timeout: TimeInterval = 5, fileID: String = #fileID, line: UInt = #line) async throws {
        try await fleetAttributing(fileID, line) {
            try requireActive("wait for hosted view readiness")
            try await context.waitUntil("hosted SwiftUI view to be ready (mounted, positive size)", timeout: timeout) { self.isReady }
        }
    }

    /// Waits (bounded) for SwiftUI's `onAppear` on the hosted root: a distinct event from mounting.
    public func waitForAppearance(timeout: TimeInterval = 5, fileID: String = #fileID, line: UInt = #line) async throws {
        try await fleetAttributing(fileID, line) {
            try requireActive("wait for hosted view appearance")
            try await context.waitUntil("hosted SwiftUI view to appear", timeout: timeout) { self.lifecycle.isAppeared }
        }
    }

    /// Waits (bounded) for `condition`, evaluated against live application state after an update.
    public func waitForUpdate(
        _ description: String,
        timeout: TimeInterval = 5,
        fileID: String = #fileID,
        line: UInt = #line,
        condition: @MainActor () -> Bool
    ) async throws {
        try await fleetAttributing(fileID, line) {
            try requireActive("wait for hosted view update")
            try await context.waitUntil(description, timeout: timeout, condition: condition)
        }
    }

    /// Waits (bounded) until the named observed task has started `count` times in total.
    public func waitForTaskStart(_ name: String, count: Int = 1, timeout: TimeInterval = 5, fileID: String = #fileID, line: UInt = #line) async throws {
        try await fleetAttributing(fileID, line) {
            try requireActive("wait for task start")
            try await context.waitUntil("observed task '\(name)' to start \(count) time(s)", timeout: timeout) {
                self.lifecycle.count(of: .taskStarted(name: name)) >= count
            }
        }
    }

    /// Waits (bounded) until the named observed task has been cancelled `count` times in total.
    public func waitForTaskCancellation(_ name: String, count: Int = 1, timeout: TimeInterval = 5, fileID: String = #fileID, line: UInt = #line) async throws {
        try await fleetAttributing(fileID, line) {
            try requireActive("wait for task cancellation")
            try await context.waitUntil("observed task '\(name)' to be cancelled \(count) time(s)", timeout: timeout) {
                self.lifecycle.count(of: .taskCancelled(name: name)) >= count
            }
        }
    }

    /// Removes the hosted screen from the window (dismissal/removal), then waits (bounded) for
    /// SwiftUI's `onDisappear`. Removal and disappearance are separate observations.
    public func remove(timeout: TimeInterval = 5, fileID: String = #fileID, line: UInt = #line) async throws {
        try await fleetAttributing(fileID, line) {
            try requireActive("remove hosted view")
            removeFromWindow()
            try await context.waitUntil("hosted SwiftUI view to disappear", timeout: timeout) { !self.lifecycle.isAppeared }
        }
    }

    func removeFromWindow() {
        guard !isRemoved else { return }
        isRemoved = true
        if context.window.rootViewController === hostingController {
            context.window.rootViewController = nil
        }
    }

    /// Cleanup: removes the screen, then gives SwiftUI's `onDisappear` and observed-task
    /// cancellation a bounded, cancellation-immune chance to be delivered, so no hosted work or
    /// application cleanup leaks into the next scope. The two are awaited independently.
    func dismantle(drainTimeout: TimeInterval = 2) async {
        removeFromWindow()
        let deadline = Date().addingTimeInterval(drainTimeout)
        func tasksRunning() -> Bool {
            let started = lifecycle.events.filter { if case .taskStarted = $0 { return true }; return false }.count
            let ended = lifecycle.events.filter {
                switch $0 { case .taskCancelled, .taskFinished: return true; default: return false }
            }.count
            return ended < started
        }
        // Only a screen that actually appeared is owed a disappearance.
        while (lifecycle.isAppeared || tasksRunning()), deadline.timeIntervalSinceNow > 0 {
            await Task { @MainActor in try? await Task.sleep(nanoseconds: 10_000_000) }.value
        }
    }
}

extension FleetTestContext {
    /// Lower-level route: installs `view` as the window root and returns the handle immediately.
    /// It does not call `layoutIfNeeded` and does not wait, so the caller can exercise an initial
    /// zero-size sequence, then call `layoutIfNeeded()` and the wait methods explicitly. The
    /// handle's mounted state is dismantled at scope end by `Fleet.withHostedView`; if you mount
    /// directly in `withContext`, call `remove()` or rely on the context restoring the window.
    public func mount<Content: View>(_ view: Content, fileID: String = #fileID, line: UInt = #line) throws -> FleetHostedView {
        guard isActive else { throw Self.contextEnded.attributed(to: FleetSourceLocation(fileID: fileID, line: line)) }
        let recorder = FleetLifecycleRecorder()
        let controller = UIHostingController(rootView: AnyView(FleetProbeRoot(recorder: recorder, content: AnyView(view))))
        let handle = FleetHostedView(context: self, hostingController: controller, lifecycle: recorder)
        window.endEditing(true)
        window.rootViewController = controller
        // Scope end removes the screen and drains disappearance and observed-task cancellation,
        // on every route (`host`, `mount`, `withHostedView`) and every exit.
        try addAsyncCleanup { await handle.dismantle() }
        return handle
    }

    /// Convenience route: `mount`, then waits (bounded) for mounting, readiness and appearance.
    public func host<Content: View>(
        _ view: Content,
        timeout: TimeInterval = 5,
        fileID: String = #fileID,
        line: UInt = #line
    ) async throws -> FleetHostedView {
        let handle = try mount(view, fileID: fileID, line: line)
        window.layoutIfNeeded()
        try await handle.waitUntilMounted(timeout: timeout, fileID: fileID, line: line)
        try await handle.waitUntilReady(timeout: timeout, fileID: fileID, line: line)
        try await handle.waitForAppearance(timeout: timeout, fileID: fileID, line: line)
        return handle
    }
}

extension Fleet {
    /// Hosts `view` in a borrowed `window` for the duration of `body`. On return, throw, timeout
    /// or cancellation the screen is removed, observed tasks get a bounded chance to observe
    /// cancellation, and the window is restored. Inject application-owned environment objects
    /// into `view` yourself (`.environmentObject(...)`); Fleet does not own your dependencies.
    @MainActor
    public static func withHostedView<Content: View, T>(
        _ view: Content,
        window: UIWindow,
        fileID: String = #fileID,
        line: UInt = #line,
        _ body: @MainActor (FleetHostedView) async throws -> T
    ) async throws -> T {
        try await withContext(window: window) { context in
            try await hosted(view, in: context, fileID: fileID, line: line, body)
        }
    }

    /// As `withHostedView(_:window:_:)`, creating an owned window for the explicit `scene`.
    @MainActor
    public static func withHostedView<Content: View, T>(
        _ view: Content,
        scene: UIWindowScene,
        fileID: String = #fileID,
        line: UInt = #line,
        _ body: @MainActor (FleetHostedView) async throws -> T
    ) async throws -> T {
        try await withContext(scene: scene) { context in
            try await hosted(view, in: context, fileID: fileID, line: line, body)
        }
    }

    @MainActor
    private static func hosted<Content: View, T>(
        _ view: Content,
        in context: FleetTestContext,
        fileID: String,
        line: UInt,
        _ body: @MainActor (FleetHostedView) async throws -> T
    ) async throws -> T {
        let handle = try context.mount(view, fileID: fileID, line: line)
        try await handle.waitUntilMounted(fileID: fileID, line: line)
        context.window.layoutIfNeeded()
        try await handle.waitUntilReady(fileID: fileID, line: line)
        try await handle.waitForAppearance(fileID: fileID, line: line)
        return try await body(handle)
    }
}
