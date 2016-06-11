import UIKit

public extension UIBarButtonItem {
    public func tap() {
        if action != nil {
            if let target = target {
                target.performSelector(action, withObject: self)
            }
        }
    }
}
