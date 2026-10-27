#if os(macOS)
import AppKit
import SwiftUI

/// A failure reported by the macOS hosting API. It names the operation and the observed state.
public struct FleetMacOSFailure: Error, CustomStringConvertible, Sendable {
    public enum Kind: Sendable, Equatable {
        case timedOut
        case invalidInput
        case invalidSetup
    }

    public let kind: Kind
    public let action: String
    public let state: String
    public let reason: String

    public var description: String {
        "Fleet (macOS) could not \(action). State: \(state) \(reason)"
    }
}

/// Process-local FIFO lease. At most one hosting scope holds it, from before setup until after
/// cleanup. Main-actor isolated; a cancelled waiter never holds or leaks the lease.
@MainActor
final class FleetMacOSCoordinator {
    static let shared = FleetMacOSCoordinator()

    private struct Waiter {
        let id: UInt64
        let continuation: CheckedContinuation<Void, Error>
    }

    private var held = false
    private var waiters: [Waiter] = []
    private var nextID: UInt64 = 0

    var isHeld: Bool { held }
    var waiterCount: Int { waiters.count }

    func acquire() async throws {
        if Task.isCancelled { throw CancellationError() }
        if !held {
            held = true
            return
        }
        nextID += 1
        let id = nextID
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiters.append(Waiter(id: id, continuation: continuation))
                }
            }
        } onCancel: {
            Task { @MainActor in self.cancelWaiter(id) }
        }
        // The lease may have been handed over before the cancellation was processed.
        if Task.isCancelled {
            release()
            throw CancellationError()
        }
    }

    private func cancelWaiter(_ id: UInt64) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }

    func release() {
        precondition(held, "Fleet macOS lease released without being held")
        if waiters.isEmpty {
            held = false
        } else {
            waiters.removeFirst().continuation.resume()
        }
    }
}

/// Records SwiftUI's real appear/disappear delivery for the hosted root.
@MainActor
final class FleetMacOSLifecycle {
    var appearCount = 0
    var disappearCount = 0
}

private struct LifecycleReporter<Content: View>: View {
    let lifecycle: FleetMacOSLifecycle
    let content: Content

    var body: some View {
        content
            .onAppear { lifecycle.appearCount += 1 }
            .onDisappear { lifecycle.disappearCount += 1 }
    }
}

/// A scoped SwiftUI host in an `NSWindow`, created by `FleetMacOS.withHostedView`.
///
/// Use it only inside the body passed to `withHostedView`. It observes the mounted SwiftUI
/// hierarchy (mounted, appeared, application state you name, removed). It does not send physical
/// input, prove hit testing or accessibility, or exercise OS authentication.
@MainActor
public final class FleetMacOSHost {
    public let window: NSWindow
    public let ownsWindow: Bool
    public let hostingController: NSHostingController<AnyView>

    let lifecycle = FleetMacOSLifecycle()
    private(set) var isActive = true
    private var cleanups: [@MainActor () -> Void] = []
    private var previousContent: NSViewController?
    private var previousContentView: NSView?
    private var previousContentRect: NSRect = .zero
    private var previousMinSize: NSSize = .zero
    private var previousMaxSize: NSSize = .zero
    private var wasVisible = false

    init<V: View>(view: V, window: NSWindow?) {
        let lifecycle = self.lifecycle
        hostingController = NSHostingController(rootView: AnyView(LifecycleReporter(lifecycle: lifecycle, content: view)))
        if let window {
            self.window = window
            ownsWindow = false
        } else {
            let owned = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            owned.isReleasedWhenClosed = false
            self.window = owned
            ownsWindow = true
        }
    }

    static var scopeEnded: FleetMacOSFailure {
        FleetMacOSFailure(
            kind: .invalidSetup,
            action: "use the hosted view",
            state: "its `withHostedView` scope has already ended.",
            reason: "Use the host only inside the body passed to `FleetMacOS.withHostedView`."
        )
    }

    /// Whether SwiftUI has delivered `onAppear` / `onDisappear` for the root, as counts.
    public var appearCount: Int { lifecycle.appearCount }
    public var disappearCount: Int { lifecycle.disappearCount }

    /// `true` once the hosting view is in the window and has a positive size.
    public var isReady: Bool {
        let view = hostingController.view
        return view.window === window && view.bounds.width > 0 && view.bounds.height > 0
    }

    /// Replaces the hosted root view (for example to reflect injected state) without remounting the window.
    public func update<V: View>(_ view: V) throws {
        guard isActive else { throw Self.scopeEnded }
        hostingController.rootView = AnyView(LifecycleReporter(lifecycle: lifecycle, content: view))
    }

    /// Registers work to run (last registered first) when the scope ends, whether the body
    /// returns, throws, times out or is cancelled. Use it for resources the host owns, such as observers.
    public func addCleanup(_ cleanup: @escaping @MainActor () -> Void) throws {
        guard isActive else { throw Self.scopeEnded }
        cleanups.append(cleanup)
    }

    /// Polls `condition` on the main actor, yielding between checks so AppKit and SwiftUI can
    /// make progress. Throws `.timedOut` at the deadline, `.invalidInput` for a non-finite
    /// timeout or a non-positive poll interval, or the unchanged `CancellationError`.
    public func waitUntil(
        _ description: String,
        timeout: TimeInterval = 5,
        pollInterval: TimeInterval = 0.01,
        condition: @MainActor () -> Bool
    ) async throws {
        guard isActive else { throw Self.scopeEnded }
        guard pollInterval.isFinite, pollInterval > 0 else {
            throw FleetMacOSFailure(
                kind: .invalidInput,
                action: "wait for \(description)",
                state: "pollInterval was \(pollInterval).",
                reason: "Pass a finite pollInterval greater than zero."
            )
        }
        guard timeout.isFinite else {
            throw FleetMacOSFailure(
                kind: .invalidInput,
                action: "wait for \(description)",
                state: "timeout was \(timeout).",
                reason: "Pass a finite timeout so the wait is bounded."
            )
        }
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            try Task.checkCancellation()
            // Re-checked after every suspension so a wait cannot outlive its scope.
            guard isActive else { throw Self.scopeEnded }
            if condition() { return }
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                throw FleetMacOSFailure(
                    kind: .timedOut,
                    action: "wait for \(description)",
                    state: "not observed within \(timeout)s. \(snapshot())",
                    reason: "Wait for a state that occurs, or raise the timeout."
                )
            }
            try await Task.sleep(nanoseconds: UInt64(min(pollInterval, remaining) * 1_000_000_000))
        }
    }

    public func waitUntilMounted(timeout: TimeInterval = 5) async throws {
        try await waitUntil("hosting view to be in the window", timeout: timeout) {
            self.hostingController.view.window === self.window
        }
    }

    public func waitUntilReady(timeout: TimeInterval = 5) async throws {
        try await waitUntil("hosting view to be ready", timeout: timeout) {
            self.window.contentView?.layoutSubtreeIfNeeded()
            return self.isReady
        }
    }

    public func waitForAppearance(timeout: TimeInterval = 5) async throws {
        try await waitUntil("SwiftUI onAppear", timeout: timeout) { self.lifecycle.appearCount > 0 }
    }

    /// Waits for application state that you name; Fleet does not flush arbitrary work.
    public func waitForUpdate(_ description: String, timeout: TimeInterval = 5, condition: @MainActor () -> Bool) async throws {
        try await waitUntil(description, timeout: timeout, condition: condition)
    }

    func snapshot() -> String {
        "Window state: isVisible=\(window.isVisible), isKey=\(window.isKeyWindow), size=\(window.frame.size), "
            + "mounted=\(hostingController.view.window === window), appeared=\(lifecycle.appearCount), disappeared=\(lifecycle.disappearCount)."
    }

    // MARK: Lifecycle

    func setUp() {
        previousContent = window.contentViewController
        previousContentView = previousContent == nil ? window.contentView : nil
        previousContentRect = window.frame
        previousMinSize = window.contentMinSize
        previousMaxSize = window.contentMaxSize
        wasVisible = window.isVisible
        window.contentViewController = hostingController
        if ownsWindow {
            window.setContentSize(NSSize(width: 480, height: 640))
        }
        window.contentView?.layoutSubtreeIfNeeded()
        window.orderFront(nil)
    }

    func tearDown() async -> Error? {
        isActive = false
        while let cleanup = cleanups.popLast() { cleanup() }
        var failure: Error?
        // Dismantle the root, then wait (bounded, immune to task cancellation) for onDisappear.
        let appeared = lifecycle.appearCount > 0
        if ownsWindow {
            window.contentViewController = nil
        } else {
            window.contentViewController = previousContent
            if previousContent == nil, let view = previousContentView {
                window.contentViewController = nil
                window.contentView = view
            }
            window.contentMinSize = previousMinSize
            window.contentMaxSize = previousMaxSize
            window.setFrame(previousContentRect, display: false)
        }
        if appeared {
            let deadline = Date().addingTimeInterval(2)
            while lifecycle.disappearCount < lifecycle.appearCount, deadline.timeIntervalSinceNow > 0 {
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            if lifecycle.disappearCount < lifecycle.appearCount {
                failure = FleetMacOSFailure(
                    kind: .timedOut,
                    action: "wait for SwiftUI onDisappear during cleanup",
                    state: "not observed within 2s. \(snapshot())",
                    reason: "The hosted view did not report removal."
                )
            }
        }
        if ownsWindow {
            window.orderOut(nil)
            window.close()
        } else if !wasVisible {
            window.orderOut(nil)
        }
        previousContent = nil
        previousContentView = nil
        cleanups.removeAll()
        return failure
    }
}

/// Entry points for scoped macOS hosting. Test-only: link this product into test bundles.
public enum FleetMacOS {
    /// Hosts `view` in an `NSHostingController` inside `window` (borrowed; its content controller,
    /// frame and visibility are restored) or, when `window` is `nil`, in a window the scope owns
    /// and closes.
    ///
    /// The scope holds a process-local FIFO lease from before setup until after cleanup, so
    /// overlapping async tests run one at a time. Cleanup (registered cleanups, root removal,
    /// bounded wait for `onDisappear`, window restore) runs on return, thrown error and
    /// cancellation. Nesting is unsupported and throws `.invalidSetup` before touching UI.
    @MainActor
    public static func withHostedView<V: View, T>(
        _ view: V,
        window: NSWindow? = nil,
        _ body: @MainActor (FleetMacOSHost) async throws -> T
    ) async throws -> T {
        if let enclosing = FleetMacOSHost.current, enclosing.isActive {
            throw FleetMacOSFailure(
                kind: .invalidSetup,
                action: "start a nested `FleetMacOS.withHostedView` scope",
                state: "an enclosing scope is still active in this task and holds the lease.",
                reason: "Use the enclosing host, or end it before starting another."
            )
        }
        let coordinator = FleetMacOSCoordinator.shared
        try await coordinator.acquire()
        let host = FleetMacOSHost(view: view, window: window)
        host.setUp()
        let value: T
        do {
            value = try await FleetMacOSHost.$current.withValue(host) {
                try await body(host)
            }
        } catch {
            _ = await host.tearDown()
            coordinator.release()
            throw error
        }
        let cleanupError = await host.tearDown()
        coordinator.release()
        if let cleanupError { throw cleanupError }
        return value
    }
}

extension FleetMacOSHost {
    @TaskLocal static var current: FleetMacOSHost?
}
#endif
