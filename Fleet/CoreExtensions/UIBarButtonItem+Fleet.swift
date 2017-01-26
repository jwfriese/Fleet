import UIKit

extension Fleet {
    public enum BarButtonItemError: Error, CustomStringConvertible {
        case controlUnavailable(message: String)
        case noTarget(title: String)
        case noAction(title: String)

        public var description: String {
            switch self {
            case .controlUnavailable(let message):
                return "Cannot tap UIBarButtonItem: \(message)"
            case .noTarget(let title):
                return "Attempted to tap UIBarButtonItem (title='\(title)') with no associated target."
            case .noAction(let title):
                return "Attempted to tap UIBarButtonItem (title='\(title)') with no associated action."
            }
        }
    }
}

extension UIBarButtonItem {

    /**
     Mimic a user tap on the bar button, firing any associated events.

     - throws:
     A `Fleet.BarButtonItemError` if the bar button is not enabled, if it does not have
     a target, or if it does not have an action.
     */
    public func tap() throws {
        guard isEnabled else {
            throw Fleet.BarButtonItemError.controlUnavailable(message: "Control is not enabled.")
        }

        guard let target = target else {
            throw Fleet.BarButtonItemError.noTarget(title: safeTitle)
        }

        guard let action = action else {
            throw Fleet.BarButtonItemError.noAction(title: safeTitle)
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
