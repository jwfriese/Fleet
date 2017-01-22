import UIKit

public protocol FLTScreen {
    /**
     Gives access to the topmost view controller on the screen. It returns the `UIViewController`
     visually at the very top of the `FLTScreen`'s view hierarchy.
     */
    var topmostViewController: UIViewController? { get }

    /**
     Gives access to the topmost alert on the screen. It returns the `UIAlertController`
     visually at the very top of the `FLTScreen`'s view hierarchy.

     - note:
     This method should perform in a functionally equivalent manner to:
     ```
     let screen: FLTScreen
     // get a screen
     let alertController = screen.topmostViewController as? UIAlertController
     ```
     */
    var presentedAlert: UIAlertController? { get }
}
