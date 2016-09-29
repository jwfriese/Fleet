import Foundation

public extension UIAlertController {
    /**
        Mimics a tap on the alert item with the given title,
        firing any associated behavior.

        - Parameter title:  The title of the action to tap
    */
    public func tapAlertAction(withTitle title: String) {
        let filteredActions = actions.filter { action in
            return action.title == title
        }

        if let actionWithTitle = filteredActions.first {
            let isCancelStyle = actionWithTitle.style == .cancel
            if let handler = actionWithTitle.handler {
                handler(actionWithTitle)
            } else {
                if !isCancelStyle {
                    Logger.logWarning("Action with title \"\(title)\" has no handler and is not Cancel style")
                }
            }

            presentingViewController?.dismiss(animated: true, completion: nil)
        } else {
            Logger.logWarning("No action with title \"\(title)\" found on alert")
        }
    }
}
