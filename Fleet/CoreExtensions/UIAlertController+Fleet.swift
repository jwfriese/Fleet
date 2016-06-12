import Foundation

public extension UIAlertController {
    public func tapAlertActionWithTitle(title: String) {
        let filteredActions = actions.filter { action in
            return action.title == title
        }
        
        if let actionWithTitle = filteredActions.first {
            if let handler = actionWithTitle.handler {
                handler(actionWithTitle)
            } else {
                Logger.logWarning("Action with title \"\(title)\" has no handler")
            }
        } else {
            Logger.logWarning("No action with title \"\(title)\" found on alert")
        }
    }
}
