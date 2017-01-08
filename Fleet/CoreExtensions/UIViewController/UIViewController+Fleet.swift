import UIKit
import ObjectiveC

private var presentedViewControllerAssociatedKey: UInt = 0
private var presentingViewControllerAssociatedKey: UInt = 0
private var viewDidLoadCallCountAssociatedKey: UInt = 0

fileprivate var didSwizzle = false

extension UIViewController {
    open override class func initialize() {
        super.initialize()
        if !didSwizzle {
            swizzleViewDidLoad()
            swizzlePresent()
            swizzleDismiss()
            didSwizzle = true
        }
    }

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

    fileprivate class func swizzleViewDidLoad() {
        let originalSelector = #selector(UIViewController.viewDidLoad)
        let swizzledSelector = #selector(UIViewController.fleet_viewDidLoad)

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_viewDidLoad() {
        fleet_viewDidLoad()
        viewDidLoadCallCount += 1
    }

    fileprivate class func swizzlePresent() {
        let originalSelector = #selector(UIViewController.present(_:animated:completion:))
        let swizzledSelector = #selector(UIViewController.fleet_present(viewController:animated:completion:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_present(viewController: UIViewController, animated: Bool, completion: (() -> ())?) {
        fleet_present(viewController: viewController, animated: false, completion: completion)
    }

    fileprivate class func swizzleDismiss() {
        let originalSelector = #selector(UIViewController.dismiss(animated:completion:))
        let swizzledSelector = #selector(UIViewController.fleet_dismiss(animated:completion:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_dismiss(animated: Bool, completion: (() -> ())?) {
        fleet_dismiss(animated: false, completion: completion)
    }
}
