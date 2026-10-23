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
    /// Set once the screen is being torn down; observed tasks that have not yet started will not run.
    private(set) var isClosed = false

    public init() {}

    private struct ContentEntry {
        let instance: Int
        var identity: String
        var values: [String: String]
        weak var view: UIView?
    }
    private var contentEntries: [ContentEntry] = []
    private var nextContentInstance = 1
    private var mountCounts: [String: Int] = [:]

    func registerContent(identity: String, values: [String: String], view: UIView) -> Int {
        let instance = nextContentInstance
        nextContentInstance += 1
        mountCounts[identity, default: 0] += 1
        contentEntries.append(ContentEntry(instance: instance, identity: identity, values: values, view: view))
        return instance
    }

    func updateContent(instance: Int, identity: String, values: [String: String]) {
        guard let index = contentEntries.firstIndex(where: { $0.instance == instance }) else { return }
        // SwiftUI may reuse the probe in place while the content now stands for a different identity.
        if contentEntries[index].identity != identity {
            contentEntries[index].identity = identity
            mountCounts[identity, default: 0] += 1
        }
        contentEntries[index].values = values
    }

    func unregisterContent(instance: Int) {
        contentEntries.removeAll { $0.instance == instance }
    }

    /// Content whose probe is still registered with SwiftUI, whether or not it is currently in the window.
    var hasRegisteredContent: Bool { !contentEntries.isEmpty }
    func hasRegisteredContent(identity: String) -> Bool { contentEntries.contains { $0.identity == identity } }

    /// Content currently displayed: registered and in the window, in presentation order.
    var displayedContent: [FleetObservedContent] {
        contentEntries.compactMap { entry in
            guard entry.view?.window != nil else { return nil }
            return FleetObservedContent(identity: entry.identity, values: entry.values, instance: entry.instance)
        }
    }

    func mountCount(of identity: String) -> Int { mountCounts[identity] ?? 0 }

    func record(_ event: FleetLifecycleEvent) { events.append(event) }
    func close() { isClosed = true }
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
            // A start SwiftUI delivers after teardown began must not enter application code.
            if recorder?.isClosed == true { return }
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

/// One piece of application content that is actually displayed, as reported by the content itself.
public struct FleetObservedContent: Sendable, Equatable {
    /// The identity the content reported through `fleetObservedContent(_:_:)`, such as "recipe-detail".
    public let identity: String
    /// The values the content reported it is displaying, such as `["recipe": "Soup", "image": "soup.png"]`.
    public let values: [String: String]
    /// Distinguishes one mounting of this content from the next; a new presentation gets a new instance.
    public let instance: Int
}

private struct FleetContentProbe: UIViewRepresentable {
    let identity: String
    let values: [String: String]

    final class Coordinator {
        var recorder: FleetLifecycleRecorder?
        var instance: Int?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        guard let recorder = context.environment.fleetLifecycleRecorder else { return }
        let coordinator = context.coordinator
        coordinator.recorder = recorder
        if let instance = coordinator.instance {
            recorder.updateContent(instance: instance, identity: identity, values: values)
        } else {
            coordinator.instance = recorder.registerContent(identity: identity, values: values, view: view)
        }
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        guard let instance = coordinator.instance else { return }
        coordinator.recorder?.unregisterContent(instance: instance)
        coordinator.instance = nil
    }
}

extension View {
    /// Reports the content this view is displaying to the enclosing Fleet host: a stable `identity`
    /// and the `values` it actually renders (for example the recipe name and image it was given).
    /// Attach it inside the destination or sheet content, using the same values the content draws,
    /// not the model's presentation flag. It is a supported semantic seam: Fleet never inspects
    /// private SwiftUI controllers. Outside a Fleet host it does nothing.
    public func fleetObservedContent(_ identity: String, _ values: [String: String] = [:]) -> some View {
        background(FleetContentProbe(identity: identity, values: values).frame(width: 0, height: 0).allowsHitTesting(false))
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
    private let source: FleetSourceLocation?

    init(context: FleetTestContext, hostingController: UIHostingController<AnyView>, lifecycle: FleetLifecycleRecorder, source: FleetSourceLocation? = nil) {
        self.source = source
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
    public func layoutIfNeeded(fileID: String = #fileID, line: UInt = #line) throws {
        do {
            try requireActive("lay out hosted view")
        } catch let failure as FleetFailure {
            throw failure.attributed(to: FleetSourceLocation(fileID: fileID, line: line))
        }
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
            if lifecycle.count(of: .appeared) == 0 && !isRemoved {
                // SwiftUI may still owe the first `onAppear`; deliver it (bounded) so the
                // disappearance wait below covers the full appear/disappear pair.
                hostingController.view.setNeedsLayout()
                context.window.layoutIfNeeded()
                let appearDeadline = Date().addingTimeInterval(min(timeout, 0.5))
                while lifecycle.count(of: .appeared) == 0, appearDeadline.timeIntervalSinceNow > 0 {
                    await Task { @MainActor in try? await Task.sleep(nanoseconds: 10_000_000) }.value
                }
            }
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
    /// application cleanup leaks into the next scope. Observed tasks SwiftUI has not started yet
    /// are prevented from starting. Throws `.timedOut` if the outstanding work is still alive at
    /// the deadline; Fleet does not force-cancel it.
    func dismantle(drainTimeout: TimeInterval = 2) async throws {
        lifecycle.close()
        if lifecycle.count(of: .appeared) == 0 {
            // An immediate mount (or one removed right away) may still owe SwiftUI's `onAppear`.
            // Deliver it now (bounded) so the matching `onDisappear` follows removal inside this
            // scope, not the next one.
            if !isRemoved {
                hostingController.view.setNeedsLayout()
                context.window.layoutIfNeeded()
            }
            let appearDeadline = Date().addingTimeInterval(0.5)
            while lifecycle.count(of: .appeared) == 0, appearDeadline.timeIntervalSinceNow > 0 {
                await Task { @MainActor in try? await Task.sleep(nanoseconds: 10_000_000) }.value
            }
        }
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
        while lifecycle.isAppeared || tasksRunning() || !lifecycle.displayedContent.isEmpty, deadline.timeIntervalSinceNow > 0 {
            await Task { @MainActor in try? await Task.sleep(nanoseconds: 10_000_000) }.value
        }
        var outstanding: [String] = []
        if lifecycle.isAppeared { outstanding.append("onDisappear was not delivered") }
        if tasksRunning() { outstanding.append("observed task(s) had not finished after cancellation") }
        if !lifecycle.displayedContent.isEmpty { outstanding.append("observed content was still displayed") }
        guard outstanding.isEmpty else {
            throw FleetFailure(
                kind: .timedOut,
                action: "tear down hosted view",
                target: "FleetHostedView",
                state: "\(outstanding.joined(separator: "; ")) within \(drainTimeout)s. \(context.snapshot())",
                reason: "Make observed task bodies return promptly on cancellation, or finish application cleanup before the scope ends.",
                source: source
            )
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
        let handle = FleetHostedView(context: self, hostingController: controller, lifecycle: recorder, source: FleetSourceLocation(fileID: fileID, line: line))
        window.endEditing(true)
        window.rootViewController = controller
        // Scope end removes the screen and drains disappearance and observed-task cancellation,
        // on every route (`host`, `mount`, `withHostedView`) and every exit.
        try addAsyncCleanup { try await handle.dismantle() }
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

// MARK: Presented content observation

extension FleetHostedView {
    /// Content currently displayed (registered by `fleetObservedContent` and in the window), oldest first.
    public var observedContent: [FleetObservedContent] { lifecycle.displayedContent }

    /// The most recently presented displayed content with `identity`, if any.
    public func currentContent(_ identity: String) -> FleetObservedContent? {
        lifecycle.displayedContent.last { $0.identity == identity }
    }

    /// How many times content with `identity` has been mounted since the screen was hosted.
    public func presentationCount(of identity: String) -> Int { lifecycle.mountCount(of: identity) }

    private func describeContent() -> String {
        let all = lifecycle.displayedContent
        if all.isEmpty { return "no observed content is displayed" }
        return "displayed content: " + all.map { "\($0.identity)#\($0.instance) \($0.values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))" }.joined(separator: "; ")
    }

    /// `waitUntil` whose timeout failure names the content displayed at the deadline, not at wait entry.
    private func waitForContentCondition(_ description: String, timeout: TimeInterval, condition: @MainActor () -> Bool) async throws {
        do {
            try await context.waitUntil(description, timeout: timeout, condition: condition)
        } catch let failure as FleetFailure where failure.kind == .timedOut {
            throw FleetFailure(
                kind: failure.kind,
                action: "wait for \(description); currently \(describeContent())",
                target: failure.target,
                state: failure.state,
                reason: failure.reason,
                source: failure.source
            )
        }
    }

    /// Waits (bounded) until content with `identity` is displayed, the `count`th time it has been
    /// mounted (use `count: 2` to observe a repeated presentation). This establishes presentation only.
    public func waitForContentPresented(_ identity: String, count: Int = 1, timeout: TimeInterval = 5, fileID: String = #fileID, line: UInt = #line) async throws {
        try await fleetAttributing(fileID, line) {
            try requireActive("wait for content presentation")
            try await waitForContentCondition("content '\(identity)' to be presented (mounting \(count))", timeout: timeout) {
                self.lifecycle.mountCount(of: identity) >= count && self.currentContent(identity) != nil
            }
        }
    }

    /// Waits (bounded) until the displayed content with `identity` reports every entry of `values`.
    /// This is content readiness, distinct from presentation: stale values keep it from completing,
    /// and the timeout names what was actually displayed.
    public func waitForContent(_ identity: String, values: [String: String], timeout: TimeInterval = 5, fileID: String = #fileID, line: UInt = #line) async throws {
        try await fleetAttributing(fileID, line) {
            try requireActive("wait for content values")
            let expected = values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            try await waitForContentCondition("content '\(identity)' to display \(expected)", timeout: timeout) {
                guard let current = self.currentContent(identity) else { return false }
                return values.allSatisfy { current.values[$0.key] == $0.value }
            }
        }
    }

    /// Waits (bounded) until no content with `identity` remains displayed or registered: completed dismissal.
    public func waitForContentDismissed(_ identity: String, timeout: TimeInterval = 5, fileID: String = #fileID, line: UInt = #line) async throws {
        try await fleetAttributing(fileID, line) {
            try requireActive("wait for content dismissal")
            try await waitForContentCondition("content '\(identity)' to be dismissed", timeout: timeout) {
                self.lifecycle.displayedContent.allSatisfy { $0.identity != identity }
                    && !self.lifecycle.hasRegisteredContent(identity: identity)
            }
        }
    }

    /// Waits (bounded) until the hosting controller presents no UIKit modal (a completed sheet dismissal).
    /// Sheets only: navigation pushes are not modal presentations.
    public func waitForModalDismissal(timeout: TimeInterval = 5, fileID: String = #fileID, line: UInt = #line) async throws {
        try await fleetAttributing(fileID, line) {
            try requireActive("wait for modal dismissal")
            try await context.waitUntil("hosted view to present no modal controller", timeout: timeout) {
                self.hostingController.presentedViewController == nil
            }
        }
    }
}
