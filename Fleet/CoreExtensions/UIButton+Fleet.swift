import UIKit

extension UIButton {

    /**
        Mimics a user tap on the button, firing any associated events
    */
    public func tap() {
        sendActions(for: .touchUpInside)
    }
}
