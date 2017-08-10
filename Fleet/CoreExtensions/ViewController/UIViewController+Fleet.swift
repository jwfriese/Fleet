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
        let originalSelector = #selector(UIViewController.viewDidLoad)
        let swizzledSelector = #selector(UIViewController.fleet_viewDidLoad)

        guard let originalMethod = class_getInstanceMethod(self, originalSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UIViewController.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }
        guard let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UIViewController.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func fleet_viewDidLoad() {
        fleet_viewDidLoad()
        viewDidLoadCallCount += 1
    }

    @objc class func swizzlePresent() {
        let originalSelector = #selector(UIViewController.present(_:animated:completion:))
        let swizzledSelector = #selector(UIViewController.fleet_present(viewController:animated:completion:))

        guard let originalMethod = class_getInstanceMethod(self, originalSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UIViewController.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }
        guard let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UIViewController.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func fleet_present(viewController: UIViewController, animated: Bool, completion: (() -> ())?) {
        fleet_present(viewController: viewController, animated: false, completion: completion)
    }

    @objc class func swizzleDismiss() {
        let originalSelector = #selector(UIViewController.dismiss(animated:completion:))
        let swizzledSelector = #selector(UIViewController.fleet_dismiss(animated:completion:))

        guard let originalMethod = class_getInstanceMethod(self, originalSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UIViewController.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }
        guard let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UIViewController.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func fleet_dismiss(animated: Bool, completion: (() -> ())?) {
        fleet_dismiss(animated: false, completion: completion)
    }
}
