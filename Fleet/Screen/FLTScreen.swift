import UIKit

public protocol FLTScreen {
    var topmostViewController: UIViewController? { get }
    var presentedAlert: UIAlertController? { get }
}
