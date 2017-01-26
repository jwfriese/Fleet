import UIKit

extension Fleet {
    public enum AlertError: Error, CustomStringConvertible {
        case titleNotFound(title: String)

        public var description: String {
            get {
                switch self {
                case .titleNotFound(let title):
                    return "No action with title '\(title)' found on alert."
                }
            }
        }
    }
}

extension UIAlertController {
    /**
     Mimics a tap on the alert item with the given title,
     firing any associated behavior.

     - parameters:
        - title:  The title of the action to tap

     - throws:
     A `Fleet.AlertError` if an alert action with the given title cannot be found.
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
            throw Fleet.AlertError.titleNotFound(title: title)
        }
    }
}
