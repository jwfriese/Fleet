import UIKit

extension Fleet {
    enum AlertError: FleetErrorDefinition {
        case titleNotFound(title: String)

        var errorMessage: String {
            get {
                switch self {
                case .titleNotFound(let title):
                    return "No action with title '\(title)' found on alert."
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

     - parameters:
        - title:  The title of the action to tap

     - throws:
     A `FleetError` if an alert action with the given title cannot be found.
     */
    public func tapAlertAction(withTitle title: String) throws {
        let filteredActions = actions.filter { action in
            return action.title == title
        }

        var completionHandler: (() -> ())?
        if let actionWithTitle = filteredActions.first {
            if let handler = actionWithTitle.handler {
                completionHandler = {
                    handler(actionWithTitle)
                }
            }

            presentingViewController?.dismiss(animated: true, completion: completionHandler)
        } else {
            FleetError(Fleet.AlertError.titleNotFound(title: title)).raise()
        }
    }
}
