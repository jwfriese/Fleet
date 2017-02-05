import UIKit

extension Fleet {
    enum BarButtonItemError: FleetErrorDefinition {
        case controlUnavailable(message: String)
        case noTarget(title: String)
        case noAction(title: String)

        var errorMessage: String {
            switch self {
            case .controlUnavailable(let message):
                return "Cannot tap UIBarButtonItem: \(message)"
            case .noTarget(let title):
                return "Attempted to tap UIBarButtonItem (title='\(title)') with no associated target."
            case .noAction(let title):
                return "Attempted to tap UIBarButtonItem (title='\(title)') with no associated action."
            }
        }

        var name: NSExceptionName { get { return NSExceptionName(rawValue: "Fleet.BarButtonItemError") } }
    }
}

extension UIBarButtonItem {

    /**
     Mimic a user tap on the bar button, firing any associated events.

     - throws:
     A `FleetError` if the bar button is not enabled, if it does not have
     a target, or if it does not have an action.
     */
    public func tap() throws {
        guard isEnabled else {
            FleetError(Fleet.BarButtonItemError.controlUnavailable(message: "Control is not enabled.")).raise()
            return
        }

        guard let target = target else {
            FleetError(Fleet.BarButtonItemError.noTarget(title: safeTitle)).raise()
            return
        }

        guard let action = action else {
            FleetError(Fleet.BarButtonItemError.noAction(title: safeTitle)).raise()
            return
        }

        let _ = target.perform(action, with: self)
    }

    fileprivate var safeTitle: String {
        get {
            if let title = title {
                return title
            }

            return "<No Title>"
        }
    }
}
