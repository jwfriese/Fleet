import UIKit

public extension UIBarButtonItem {
    /**
        Mimic a user tap on the bar button, firing any associated events.
    */
    public func tap() {
        if isEnabled {
            if action != nil {
                if let target = target {
                    let _ = target.perform(action, with: self)
                } else {
                    Logger.logWarning("Tapped a UIBarButtonItem (title: \(self.safeTitle)) with no associated target")
                }
            } else {
                Logger.logWarning("Tapped a UIBarButtonItem (title: \(self.safeTitle)) with no associated action")
            }
        } else {
            Logger.logWarning("Attempted to tap a disabled UIBarButtonItem (title: \(self.safeTitle))")
        }
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
