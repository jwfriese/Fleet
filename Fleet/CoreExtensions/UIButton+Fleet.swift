import Foundation

public extension UIButton {
    public func tap() {
        sendActionsForControlEvents(.TouchUpInside)
    }
}
