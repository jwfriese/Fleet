import UIKit
import ObjectiveC

private var presentedViewControllerAssociatedKey: UInt = 0
private var presentingViewControllerAssociatedKey: UInt = 0
private var viewDidLoadCallCountAssociatedKey: UInt = 0

fileprivate var didSwizzle = false

extension UIViewController {
    var viewDidLoadCallCount: Int {
        get {
            return fleet_property_viewDidLoadCallCount
        }

        set {
            fleet_property_viewDidLoadCallCount = newValue
        }
    }

    fileprivate var fleet_property_viewDidLoadCallCount: Int {
        get {
            let number = objc_getAssociatedObject(self, &viewDidLoadCallCountAssociatedKey) as? NSNumber
            if let number = number {
                return number.intValue
            }

            return 0
        }

        set {
            let newNumber = NSNumber(integerLiteral: newValue)
            objc_setAssociatedObject(self, &viewDidLoadCallCountAssociatedKey, newNumber, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }

    @objc class func swizzleViewDidLoad() {
        Fleet.swizzle(
            originalSelector: #selector(UIViewController.viewDidLoad),
            swizzledSelector: #selector(UIViewController.fleet_viewDidLoad),
            forClass: self
        )
    }

    @objc func fleet_viewDidLoad() {
        fleet_viewDidLoad()
        viewDidLoadCallCount += 1
    }

    @objc class func swizzlePresent() {
        Fleet.swizzle(
            originalSelector: #selector(UIViewController.present(_:animated:completion:)),
            swizzledSelector: #selector(UIViewController.fleet_present(viewController:animated:completion:)),
            forClass: self
        )
    }

    @objc func fleet_present(viewController: UIViewController, animated: Bool, completion: (() -> ())?) {
        fleet_present(viewController: viewController, animated: false, completion: completion)
    }

    @objc class func swizzleDismiss() {
        Fleet.swizzle(
            originalSelector: #selector(UIViewController.dismiss(animated:completion:)),
            swizzledSelector: #selector(UIViewController.fleet_dismiss(animated:completion:)),
            forClass: self
        )
    }

    @objc func fleet_dismiss(animated: Bool, completion: (() -> ())?) {
        fleet_dismiss(animated: false, completion: completion)
    }
}
