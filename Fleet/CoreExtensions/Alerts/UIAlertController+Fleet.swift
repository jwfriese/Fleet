import UIKit
import ObjectiveC

extension Fleet {
    enum AlertError: FleetErrorDefinition {
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

extension UIAlertController {
    /**
     Mimics a tap on the alert item with the given title,
     firing any associated behavior.

     The alert is dismissed first (without animation); the action's handler,
     if it has one, runs in the dismissal completion, so it observes the
     presenting controller as the topmost controller. An action created
     without a handler is dismissed without further effect.

     - parameters:
        - title:  The title of the action to tap

     - throws:
     A `FleetError` if no action has the given title, if more than one action
     has it (Fleet never taps several actions for one call), if the matching
     action is disabled, or if the alert is not currently presented.
     */
    public func tapAlertAction(withTitle title: String) {
        let matchingActions = actions.filter { $0.title == title }

        guard let actionWithTitle = matchingActions.first else {
            FleetError(Fleet.AlertError.titleNotFound(title: title)).raise()
            return
        }

        guard matchingActions.count == 1 else {
            FleetError(Fleet.AlertError.ambiguousTitle(title: title, count: matchingActions.count)).raise()
            return
        }

        guard actionWithTitle.isEnabled else {
            FleetError(Fleet.AlertError.actionDisabled(title: title)).raise()
            return
        }

        guard let presenter = presentingViewController else {
            FleetError(Fleet.AlertError.notPresented(title: title)).raise()
            return
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
