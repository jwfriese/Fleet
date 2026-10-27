import UIKit
import ObjectiveC

extension Fleet {
    enum AlertError: FleetErrorDefinition, Error {
        case titleNotFound(title: String)
        case ambiguousTitle(title: String, count: Int)
        case actionDisabled(title: String)
        case notPresented(title: String)

        var errorMessage: String {
            get {
                switch self {
                case .titleNotFound(let title):
                    return "No action with title '\(title)' found on alert."
                case .ambiguousTitle(let title, let count):
                    return "\(count) actions with title '\(title)' found on alert; Fleet will not guess which to tap."
                case .actionDisabled(let title):
                    return "Cannot tap alert action with title '\(title)': Action is not enabled."
                case .notPresented(let title):
                    return "Cannot tap alert action with title '\(title)': Alert is not presented."
                }
            }
        }

        var name: NSExceptionName { get { return NSExceptionName(rawValue: "Fleet.AlertError") } }
    }
}

extension Fleet {
    /// What Fleet observed about a `UIAlertAction`'s handler through its retained private
    /// `setHandler:` hook. This is evidence of capture only; it never proves the handler works.
    public enum AlertHandlerCapture: Sendable, Equatable {
        /// The hook saw a non-nil handler being set.
        case observedHandler
        /// The hook saw `setHandler:` called with nil: the action was created without a handler.
        case observedNil
        /// The hook never saw `setHandler:` for this action. Fleet cannot tell an intentionally
        /// absent handler from one UIKit did not route through the hook.
        case unobserved
        /// The private selector was unavailable at load time, so no capture is possible.
        case unavailable
    }

    /// What `tapAlertActionStrictly(withTitle:)` did. It dismisses the presentation;
    /// it does not prove physical hit testing or accessibility.
    public enum AlertTapOutcome: Sendable, Equatable {
        /// The alert was dismissed and the observed handler returned; it ran exactly once.
        case handlerInvoked
        /// The alert was dismissed (the dismissal completed); the action was observed to have no handler, so none ran.
        case dismissedWithoutHandler
    }
}

extension Fleet {
    /// The default number of seconds `tapAlertActionStrictly` waits for UIKit's dismissal completion.
    public static let defaultAlertDismissalTimeout: TimeInterval = 10
}

/// Resumes one waiter exactly once, from a completion, a timeout, or cancellation, whichever comes first.
final class AlertCompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var result: Result<Void, Error>?
    private var timer: Task<Void, Never>?

    func install(_ continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        if let result {
            lock.unlock()
            continuation.resume(with: result)
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }

    func startTimer(seconds: TimeInterval, failure: @escaping @Sendable () -> Error) {
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(min(seconds, 86_400) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finish(.failure(failure()))
        }
        lock.lock()
        if result == nil { timer = task; lock.unlock() } else { lock.unlock(); task.cancel() }
    }

    func finish(_ outcome: Result<Void, Error>) {
        lock.lock()
        guard result == nil else { lock.unlock(); return }
        result = outcome
        let waiter = continuation
        continuation = nil
        let pending = timer
        timer = nil
        lock.unlock()
        pending?.cancel()
        waiter?.resume(with: outcome)
    }
}

extension UIAlertController {
    /**
     Reports what Fleet observed about the handler of the single action with the given title,
     without tapping it. Returns nil when no action, or more than one action, has the title.
     */
    public func alertHandlerCapture(forActionWithTitle title: String) -> Fleet.AlertHandlerCapture? {
        let matches = actions.filter { $0.title == title }
        guard matches.count == 1 else { return nil }
        return matches[0].handlerCapture
    }

    /**
     Capability-aware variant of `tapAlertActionOrThrow(withTitle:)`. It dismisses the alert
     (without animation) and invokes the action's handler exactly once, but only when Fleet
     observed that handler being set. If the capture hook is unavailable or the action's
     handler was never observed, it throws `.invalidSetup` before dismissing or running anything,
     rather than silently reporting that a handler ran. An action observed to have no handler is
     dismissed and reported as `.dismissedWithoutHandler`.

     This is asynchronous: it returns only after UIKit's dismissal completion has run, so the
     returned outcome is evidence that the handler already returned (or, for `.dismissedWithoutHandler`,
     that the dismissal completed). Handler effects can be inspected immediately afterwards.

     For behavior this interception cannot establish, invoke an application-owned command
     directly or use an XCUITest.

     The wait is bounded by `timeout` (default `Fleet.defaultAlertDismissalTimeout`, 10 seconds).
     A timeout that is not finite and positive throws `.invalidInput` before anything happens. If
     completion is not observed in time it throws `.timedOut`; that does not mean the dismissal was
     undone, and if UIKit completes it later the handler still runs (once) after the throw, so do not
     assume it never will. Cancellation is checked before any side effect and also while waiting; it
     throws `CancellationError`, with the same late-completion caveat. Duplicate or late completions
     never resume the waiter again or run the handler twice. The outcome is never reported for a
     timed-out or cancelled call.

     - throws: `FleetFailure` for the cases of `tapAlertActionOrThrow(withTitle:)`, `.invalidSetup`
       when capture evidence is missing, `.invalidInput` for an invalid timeout, and `.timedOut`.
     */
    @discardableResult
    public func tapAlertActionStrictly(withTitle title: String, timeout: TimeInterval = Fleet.defaultAlertDismissalTimeout) async throws -> Fleet.AlertTapOutcome {
        try await strictTap(withTitle: title, timeout: timeout, dismiss: nil)
    }

    /// The strict tap with an injectable dismissal, so tests can withhold, delay, or repeat completion.
    func strictTap(withTitle title: String, timeout: TimeInterval,
                   dismiss: ((UIViewController, (() -> Void)?) -> Void)?) async throws -> Fleet.AlertTapOutcome {
        let target = "UIAlertController action '\(title)'"
        guard timeout.isFinite, timeout > 0 else {
            throw FleetFailure(kind: .invalidInput, action: "tap alert action", target: target,
                state: "timeout \(timeout) is not a finite number of seconds greater than zero",
                reason: "Pass a positive, finite timeout. Nothing was dismissed or run.")
        }
        try Task.checkCancellation()
        if let action = actions.first(where: { $0.title == title }), actions.filter({ $0.title == title }).count == 1,
           action.isEnabled, presentingViewController != nil {
            switch action.handlerCapture {
            case .unavailable:
                throw FleetFailure(kind: .invalidSetup, action: "tap alert action", target: target,
                    state: "Fleet's capture hook for UIAlertAction handlers is unavailable on this UIKit (the private setHandler: selector was not found at load)",
                    reason: "Invoke the handler through an application-owned command, or use an XCUITest; tapAlertAction(withTitle:) cannot run handlers here.")
            case .unobserved:
                throw FleetFailure(kind: .invalidSetup, action: "tap alert action", target: target,
                    state: "Fleet never observed this action's handler being set, so it cannot tell a missing handler from an uncaptured one",
                    reason: "Invoke the handler through an application-owned command, or use an XCUITest. Nothing was dismissed or run.")
            case .observedNil:
                try await completedTap(withTitle: title, timeout: timeout, dismiss: dismiss)
                return .dismissedWithoutHandler
            case .observedHandler:
                break
            }
        }
        try await completedTap(withTitle: title, timeout: timeout, dismiss: dismiss)
        return .handlerInvoked
    }

    private func completedTap(withTitle title: String, timeout: TimeInterval,
                              dismiss: ((UIViewController, (() -> Void)?) -> Void)?) async throws {
        let gate = AlertCompletionGate()
        let target = "UIAlertController action '\(title)'"
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                gate.install(continuation)
                do {
                    try tapAlertActionOrThrow(withTitle: title, completion: { gate.finish(.success(())) }, dismiss: dismiss)
                } catch {
                    gate.finish(.failure(error))
                    return
                }
                gate.startTimer(seconds: timeout) {
                    FleetFailure(kind: .timedOut, action: "tap alert action", target: target,
                        state: "UIKit's dismissal completion was not observed within \(timeout) seconds; the dismissal may still complete and, if it does, the action's handler may still run later",
                        reason: "The dismissal was not undone and the handler was not cancelled. Inspect the presentation state before reusing this alert, or pass a longer timeout.")
                }
            }
        } onCancel: {
            gate.finish(.failure(CancellationError()))
        }
    }

    /**
     Mimics a tap on the alert item with the given title,
     firing any associated behavior.

     The alert is dismissed first (without animation); the action's handler,
     if it has one, runs in the dismissal completion, so it observes the
     presenting controller as the topmost controller. An action created
     without a handler, or whose handler Fleet could not capture, is dismissed without
     further effect and without any indication; use `tapAlertActionStrictly(withTitle:)`
     to distinguish those cases. This dismisses the presentation and invokes a captured handler;
     it does not prove physical interaction.

     - parameters:
        - title:  The title of the action to tap

     - throws:
     A `FleetError` if no action has the given title, if more than one action
     has it (Fleet never taps several actions for one call), if the matching
     action is disabled, or if the alert is not currently presented.
     */
    public func tapAlertAction(withTitle title: String) {
        do {
            try performTap(withTitle: title)
        } catch let error as Fleet.AlertError {
            FleetError(error).raise()
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
    }

    /**
     Like `tapAlertAction(withTitle:)`, but reports failures as a thrown `FleetFailure`
     instead of raising an `NSException`: `.invalidInput` when no action or several actions
     have the title, `.unavailableInteraction` when the action is disabled or the alert is
     not presented. Nothing is dismissed or run when it throws. Like `tapAlertAction(withTitle:)`,
     it silently dismisses an action whose handler was not captured.
     */
    public func tapAlertActionOrThrow(withTitle title: String) throws {
        try tapAlertActionOrThrow(withTitle: title, completion: nil)
    }

    private func tapAlertActionOrThrow(withTitle title: String, completion: (() -> Void)?,
                                       dismiss: ((UIViewController, (() -> Void)?) -> Void)? = nil) throws {
        do {
            try performTap(withTitle: title, completion: completion, dismiss: dismiss)
        } catch let error as Fleet.AlertError {
            let kind: FleetFailure.Kind
            switch error {
            case .titleNotFound, .ambiguousTitle: kind = .invalidInput
            case .actionDisabled, .notPresented: kind = .unavailableInteraction
            }
            throw FleetFailure(error, kind: kind, action: "tap alert action", target: "UIAlertController action '\(title)'")
        }
    }

    private func performTap(withTitle title: String, completion: (() -> Void)? = nil,
                            dismiss: ((UIViewController, (() -> Void)?) -> Void)? = nil) throws(Fleet.AlertError) {
        let matchingActions = actions.filter { $0.title == title }

        guard let actionWithTitle = matchingActions.first else {
            throw .titleNotFound(title: title)
        }

        guard matchingActions.count == 1 else {
            throw .ambiguousTitle(title: title, count: matchingActions.count)
        }

        guard actionWithTitle.isEnabled else {
            throw .actionDisabled(title: title)
        }

        guard let presenter = presentingViewController else {
            throw .notPresented(title: title)
        }

        let handler = actionWithTitle.handler
        var completed = false
        let completionHandler: (() -> ())? = (handler == nil && completion == nil) ? nil : {
            // The handler runs at most once, even if a completion is delivered again or after a timeout.
            guard !completed else { return }
            completed = true
            handler?(actionWithTitle)
            completion?()
        }

        if let dismiss {
            dismiss(presenter, completionHandler)
        } else {
            presenter.dismiss(animated: false, completion: completionHandler)
        }
    }
}
