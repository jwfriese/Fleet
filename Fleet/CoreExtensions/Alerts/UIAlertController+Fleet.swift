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

    /// What `tapAlertActionStrictlyOrThrow(withTitle:)` did. It dismisses the presentation;
    /// it does not prove physical hit testing or accessibility.
    public enum AlertTapOutcome: Sendable, Equatable {
        /// The alert was dismissed and the observed handler was invoked exactly once.
        case handlerInvoked
        /// The alert was dismissed; the action was observed to have no handler, so none ran.
        case dismissedWithoutHandler
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

     For behavior this interception cannot establish, invoke an application-owned command
     directly or use an XCUITest.

     - throws: `FleetFailure` for the cases of `tapAlertActionOrThrow(withTitle:)` and `.invalidSetup`
       when capture evidence is missing.
     */
    @discardableResult
    public func tapAlertActionStrictlyOrThrow(withTitle title: String) throws -> Fleet.AlertTapOutcome {
        let target = "UIAlertController action '\(title)'"
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
                try tapAlertActionOrThrow(withTitle: title)
                return .dismissedWithoutHandler
            case .observedHandler:
                break
            }
        }
        try tapAlertActionOrThrow(withTitle: title)
        return .handlerInvoked
    }

    /**
     Mimics a tap on the alert item with the given title,
     firing any associated behavior.

     The alert is dismissed first (without animation); the action's handler,
     if it has one, runs in the dismissal completion, so it observes the
     presenting controller as the topmost controller. An action created
     without a handler, or whose handler Fleet could not capture, is dismissed without
     further effect and without any indication; use `tapAlertActionStrictlyOrThrow(withTitle:)`
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
        do {
            try performTap(withTitle: title)
        } catch let error as Fleet.AlertError {
            let kind: FleetFailure.Kind
            switch error {
            case .titleNotFound, .ambiguousTitle: kind = .invalidInput
            case .actionDisabled, .notPresented: kind = .unavailableInteraction
            }
            throw FleetFailure(error, kind: kind, action: "tap alert action", target: "UIAlertController action '\(title)'")
        }
    }

    private func performTap(withTitle title: String) throws(Fleet.AlertError) {
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

        var completionHandler: (() -> ())?
        if let handler = actionWithTitle.handler {
            completionHandler = {
                handler(actionWithTitle)
            }
        }

        presenter.dismiss(animated: false, completion: completionHandler)
    }
}
