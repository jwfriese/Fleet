import UIKit

@MainActor
public protocol FLTScreen {
    /**
     Gives access to the visible content view controller. Starting at the window's root, it follows
     presentations, then descends into a `UINavigationController`'s `topViewController` and a
     `UITabBarController`'s `selectedViewController`, repeating until neither applies.

     An empty navigation controller or a tab bar controller without a selected controller is returned
     itself. Split view controllers and custom containers are not traversed; they are returned as-is.
     Use `topmostContainer` to reach the container.
     */
    var topmostViewController: UIViewController? { get }

    /**
     Gives access to the topmost controller in the window's presentation chain without descending into
     navigation or tab children. For a navigation stack this is the `UINavigationController` itself,
     whereas `topmostViewController` is its visible child.
     */
    var topmostContainer: UIViewController? { get }

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
