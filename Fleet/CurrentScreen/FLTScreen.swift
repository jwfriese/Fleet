import UIKit

public protocol FLTScreen {
    var topmostPresentedViewController: UIViewController? { get }
    var presentedAlert: UIAlertController? { get }
}
