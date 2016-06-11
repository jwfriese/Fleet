import UIKit

public extension UIBarButtonItem {
    public func tap() {
        if action != nil {
            if let target = target {
                target.performSelector(action, withObject: self)
            } else {
                Logger.logWarning("Tapped a UIBarButtonItem (title: \(self.title)) with no associated target")
            }
        } else {
            Logger.logWarning("Tapped a UIBarButtonItem (title: \(self.title)) with no associated action")
        }
    }
}
