import UIKit

/// A test's explicit ownership of a window, created by `Fleet.withContext`.
///
/// The context holds a process-local coordination lease for its whole lifetime (setup, body and
/// cleanup), so overlapping async tests cannot interleave their UI state. It does not make
/// UIKit work parallel-safe, and it does not flush arbitrary application work: waits observe
/// only the state or transitions you name, and fail at a deadline.
@MainActor
public final class FleetTestContext {
    /// The window this context hosts. Borrowed windows are restored; owned windows are torn down.
    public let window: UIWindow
    /// `true` when the context created `window` for a scene and will dismantle it.
    public let ownsWindow: Bool

    static var contextEnded: FleetFailure {
        FleetFailure(
            kind: .invalidSetup,
            action: "use the test context",
            target: "FleetTestContext",
            state: "its `withContext` scope has already ended",
            reason: "Use the context only inside the body passed to `Fleet.withContext`."
        )
    }

    /// The context whose `withContext` scope encloses the current asynchronous task, if any.
    /// Child tasks inherit it; detached tasks do not.
    @TaskLocal static var current: FleetTestContext?

    /// The context that should own a storyboard registration made now: the enclosing scope's
    /// context, or `nil` outside any scope. Throws if that scope has already ended, so work that
    /// outlives its context cannot leave a stale registration behind.
    static func owningContext() throws -> FleetTestContext? {
        guard let context = current else { return nil }
        guard context.isActive else { throw contextEnded }
        return context
    }

    private var cleanups: [@MainActor () -> Void] = []
    private var asyncCleanups: [@MainActor () async throws -> Void] = []
    private var adoptedBindings: [WeakStoryboardBinding] = []

    /// Arranges for this context's registrations on `binding` to be removed when the scope ends.
    func adoptStoryboardBinding(_ binding: StoryboardInstanceBinding) {
        guard !adoptedBindings.contains(where: { $0.value === binding }) else { return }
        adoptedBindings.append(WeakStoryboardBinding(binding))
    }
    private(set) var isActive = true

    init(window: UIWindow, ownsWindow: Bool) {
        self.window = window
        self.ownsWindow = ownsWindow
    }

    /// A screen wrapping this context's window.
    public var screen: FLTScreen { Fleet.getScreen(forWindow: window) }

    /// Registers work to run (last registered first) when the scope ends, whether the body
    /// returns, throws, times out or is cancelled. Use it for resources the context owns, such as
    /// observers (storyboard bindings made in the scope are removed automatically). Cleanups run before the window is restored and before
    /// the coordination lease is released.
    public func addCleanup(_ cleanup: @escaping @MainActor () -> Void) throws {
        guard isActive else { throw Self.contextEnded }
        cleanups.append(cleanup)
    }

    /// As `addCleanup`, for bounded asynchronous teardown. These run after the synchronous
    /// cleanups, last registered first, before the window is restored and the lease released.
    /// A cleanup that throws is reported after every cleanup has run, unless the body already threw.
    func addAsyncCleanup(_ cleanup: @escaping @MainActor () async throws -> Void) throws {
        guard isActive else { throw Self.contextEnded }
        asyncCleanups.append(cleanup)
    }

    /// Installs `viewController` as this window's root, finishing any editing session first,
    /// then waits (bounded) until its view is in the window.
    public func setRoot(_ viewController: UIViewController, timeout: TimeInterval = 5) async throws {
        guard isActive else { throw Self.contextEnded }
        window.endEditing(true)
        window.rootViewController = viewController
        window.layoutIfNeeded()
        try await waitUntil("root \(type(of: viewController)) to be in the context window", timeout: timeout) {
            viewController.isViewLoaded && viewController.view.window === self.window
        }
    }

    /// Installs a navigation controller rooted at `viewController` and returns it.
    @discardableResult
    public func setRootNavigation(_ viewController: UIViewController, timeout: TimeInterval = 5) async throws -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: viewController)
        try await setRoot(navigationController, timeout: timeout)
        return navigationController
    }

    /// Polls `condition` on the main actor, yielding between checks so UIKit can make progress.
    /// Throws a `FleetFailure` of kind `.timedOut` (naming `description` and a snapshot of the
    /// window) at the deadline, `.invalidInput` if `timeout` is not finite or `pollInterval` is not a finite positive number,
    /// or the task's unchanged `CancellationError` if it is cancelled.
    public func waitUntil(
        _ description: String,
        timeout: TimeInterval = 5,
        pollInterval: TimeInterval = 0.01,
        condition: @MainActor () -> Bool
    ) async throws {
        guard isActive else { throw Self.contextEnded }
        guard pollInterval.isFinite, pollInterval > 0 else {
            throw FleetFailure(
                kind: .invalidInput,
                action: "wait for \(description)",
                target: "FleetTestContext window",
                state: "pollInterval was \(pollInterval).",
                reason: "Pass a finite pollInterval greater than zero."
            )
        }
        guard timeout.isFinite else {
            throw FleetFailure(
                kind: .invalidInput,
                action: "wait for \(description)",
                target: "FleetTestContext window",
                state: "timeout was \(timeout).",
                reason: "Pass a finite timeout so the wait is bounded."
            )
        }
        let deadline = Date().addingTimeInterval(timeout)
        while true {
            try Task.checkCancellation()
            if condition() { return }
            let remaining = deadline.timeIntervalSinceNow
            if remaining <= 0 {
                throw FleetFailure(
                    kind: .timedOut,
                    action: "wait for \(description)",
                    target: "FleetTestContext window",
                    state: "not observed within \(timeout)s. \(snapshot())",
                    reason: "Wait for a state that occurs, or raise the timeout."
                )
            }
            try await Task.sleep(nanoseconds: UInt64(min(pollInterval, remaining) * 1_000_000_000))
        }
    }

    /// Waits until no view controller in the window's presentation/navigation chain reports an
    /// in-flight transition (`transitionCoordinator`). This observes UIKit transitions only.
    /// Controllers whose views are not in a window (for example a deselected tab's navigation stack) are
    /// not awaited: UIKit does not advance their animated transitions until they return on screen.
    public func waitForTransitionsToFinish(timeout: TimeInterval = 5) async throws {
        try await waitUntil("view controller transitions to finish", timeout: timeout) {
            self.transitionControllers().allSatisfy { $0.transitionCoordinator == nil || $0.viewIfLoaded?.window == nil }
        }
    }

    private func transitionControllers() -> [UIViewController] {
        var result: [UIViewController] = []
        var current = window.rootViewController
        while let controller = current {
            collectTransitionControllers(in: controller, into: &result)
            current = controller.presentedViewController
        }
        return result
    }

    /// Visits a controller and its contained children (tabs, navigation stacks, other containers),
    /// so a navigation controller nested in a non-selected or selected tab is observed too.
    private func collectTransitionControllers(in controller: UIViewController, into result: inout [UIViewController]) {
        result.append(controller)
        for child in controller.children {
            collectTransitionControllers(in: child, into: &result)
        }
        if let navigation = controller as? UINavigationController {
            for pushed in navigation.viewControllers where !result.contains(pushed) {
                collectTransitionControllers(in: pushed, into: &result)
            }
        }
        if let tabs = controller as? UITabBarController {
            for tab in tabs.viewControllers ?? [] where !result.contains(tab) {
                collectTransitionControllers(in: tab, into: &result)
            }
        }
    }

    func snapshot() -> String {
        let root = window.rootViewController.map { String(describing: type(of: $0)) } ?? "nil"
        let top = Screen(forWindow: window).topmostViewController.map { String(describing: type(of: $0)) } ?? "nil"
        return "Window state: root=\(root), topmost=\(top), isKey=\(window.isKeyWindow), isHidden=\(window.isHidden). Resolved environment: \(resolvedEnvironmentDescription())."
    }

    private func resolvedEnvironmentDescription() -> String {
        let traits = window.traitCollection
        return "size=\(window.bounds.size), style=\(traits.userInterfaceStyle.rawValue), "
            + "category=\(traits.preferredContentSizeCategory.rawValue), "
            + "horizontalSizeClass=\(traits.horizontalSizeClass.rawValue), verticalSizeClass=\(traits.verticalSizeClass.rawValue)"
    }

    // MARK: Lifecycle

    var savedEnvironment = SavedWindowEnvironment()
    private var previousRoot: UIViewController?
    private var previousKeyWindow: UIWindow?
    private var wasHidden = false

    func setUp() {
        previousKeyWindow = UIApplication.shared.keyWindow
        previousRoot = window.rootViewController
        wasHidden = window.isHidden
        if ownsWindow || !window.isKeyWindow {
            window.makeKeyAndVisible()
        }
    }

    func tearDown() async -> Error? {
        var cleanupError: Error?
        isActive = false
        let id = ObjectIdentifier(self)
        for adopted in adoptedBindings { adopted.value?.removeRegistrations(ownedBy: id) }
        adoptedBindings.removeAll()
        while let cleanup = cleanups.popLast() { cleanup() }
        while let cleanup = asyncCleanups.popLast() {
            do { try await cleanup() } catch { cleanupError = cleanupError ?? error }
        }
        window.endEditing(true)
        if let root = window.rootViewController, root.presentedViewController != nil {
            await dismissPresented(of: root)
        }
        savedEnvironment.restore(on: window)
        savedEnvironment = SavedWindowEnvironment()
        if ownsWindow {
            window.rootViewController = nil
            window.isHidden = true
            window.windowScene = nil
        } else {
            window.rootViewController = previousRoot
            window.layoutIfNeeded()
            window.isHidden = wasHidden
        }
        if let previous = previousKeyWindow, !previous.isHidden {
            previous.makeKey()
        }
        previousRoot = nil
        previousKeyWindow = nil
        cleanups.removeAll()
        return cleanupError
    }

    /// Dismisses without animation and waits (bounded, immune to task cancellation) for completion.
    private func dismissPresented(of root: UIViewController) async {
        let gate = ResumeOnce()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            gate.continuation = continuation
            root.dismiss(animated: false) { gate.fire() }
            // An unstructured task is not cancelled with the caller, so cleanup always finishes.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                gate.fire()
            }
        }
    }
}

private final class WeakStoryboardBinding {
    weak var value: StoryboardInstanceBinding?
    init(_ value: StoryboardInstanceBinding) { self.value = value }
}

@MainActor
private final class ResumeOnce {
    var continuation: CheckedContinuation<Void, Never>?
    func fire() {
        continuation?.resume()
        continuation = nil
    }
}

extension Fleet {
    /// Runs `body` with a context that borrows a known `window`. The window's root controller,
    /// key-window status and visibility are restored when the scope ends.
    ///
    /// The scope holds a process-local FIFO lease from before setup until after cleanup, so
    /// overlapping callers run one at a time. Cleanup runs on success, thrown error, timeout and
    /// cancellation. Runtime hooks stay process-wide; they are not toggled per context. The
    /// legacy global helpers (`getApplicationScreen`, `setAsAppWindowRoot`) look up the key
    /// window without coordination and must only be used serially, outside of contexts.
    ///
    /// Nesting is unsupported: calling `withContext` from inside an active scope, directly or
    /// from an awaited child task that inherits it, throws `FleetFailure(.invalidSetup)` before
    /// the lease is acquired or any UI is touched. Detached tasks do not inherit ownership, so
    /// awaiting a detached `withContext` from an active scope is also unsupported and would wait
    /// on the enclosing lease; this cannot be detected from the task-local value.
    @MainActor
    public static func withContext<T>(
        window: UIWindow,
        _ body: @MainActor (FleetTestContext) async throws -> T
    ) async throws -> T {
        try await run({ FleetTestContext(window: window, ownsWindow: false) }, body)
    }

    /// Runs `body` with a context that creates a window for the explicitly supplied `scene`,
    /// makes it key and visible, and removes it when the scope ends. No scene is looked up
    /// implicitly.
    @MainActor
    public static func withContext<T>(
        scene: UIWindowScene,
        _ body: @MainActor (FleetTestContext) async throws -> T
    ) async throws -> T {
        // The window is created only after the lease is acquired, so a queued context never
        // touches the scene during another context's lifetime.
        try await run({ FleetTestContext(window: UIWindow(windowScene: scene), ownsWindow: true) }, body)
    }

    @MainActor
    private static func run<T>(
        _ makeContext: @MainActor () -> FleetTestContext,
        _ body: @MainActor (FleetTestContext) async throws -> T
    ) async throws -> T {
        if let enclosing = FleetTestContext.current, enclosing.isActive {
            throw FleetFailure(
                kind: .invalidSetup,
                action: "start a nested `Fleet.withContext` scope",
                target: "FleetTestContext",
                state: "an enclosing `withContext` scope is still active in this task and holds the coordination lease.",
                reason: "Use the enclosing context, or end it before starting another. Detached tasks do not inherit the context, and awaiting a detached `withContext` from inside an active scope is unsupported."
            )
        }
        let coordinator = FleetContextCoordinator.shared
        try await coordinator.acquire()
        let context = makeContext()
        context.setUp()
        let value: T
        do {
            value = try await FleetTestContext.$current.withValue(context) {
                try await body(context)
            }
        } catch {
            _ = await context.tearDown()
            coordinator.release()
            throw error
        }
        let cleanupError = await context.tearDown()
        coordinator.release()
        if let cleanupError { throw cleanupError }
        return value
    }
}
