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
            swizzleShow()
            swizzlePresentedViewControllerProperty()
            swizzlePresentingViewControllerProperty()
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
        self.fleet_property_presentedViewController = viewController
        viewController.fleet_property_presentingViewController = self

        if let completion = completion {
            completion()
        }

        fleet_present(viewController: viewController, animated: animated, completion: nil)
    }

    fileprivate class func swizzleDismiss() {
        let originalSelector = #selector(UIViewController.dismiss(animated:completion:))
        let swizzledSelector = #selector(UIViewController.fleet_dismiss(animated:completion:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_dismiss(animated: Bool, completion: (() -> ())?) {
        let viewControllerToDismiss = self.fleet_property_presentedViewController

        self.fleet_property_presentedViewController = nil
        viewControllerToDismiss?.fleet_property_presentingViewController = nil

        if let completion = completion {
            completion()
        }

        fleet_dismiss(animated: animated, completion: nil)
    }

    fileprivate class func swizzleShow() {
        let originalSelector = #selector(UIViewController.show(_:sender:))
        let swizzledSelector = #selector(UIViewController.fleet_show(viewController:sender:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_show(viewController: UIViewController, sender: AnyObject?) {
        self.fleet_property_presentedViewController = viewController
        viewController.fleet_property_presentingViewController = self

        fleet_show(viewController: viewController, sender: sender)
    }

    fileprivate class func swizzlePresentedViewControllerProperty() {
        let originalSelector = #selector(getter: UIViewController.presentedViewController)
        let swizzledSelector = #selector(UIViewController.fleet_presentedViewController)

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    fileprivate var fleet_property_presentedViewController: UIViewController? {
        get {
            return objc_getAssociatedObject(self, &presentedViewControllerAssociatedKey) as? UIViewController
        }
        set {
            objc_setAssociatedObject(self, &presentedViewControllerAssociatedKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }

    func fleet_presentedViewController() -> UIViewController? {
        return self.fleet_property_presentedViewController
    }

    fileprivate class func swizzlePresentingViewControllerProperty() {
        let originalSelector = #selector(getter: UIViewController.presentingViewController)
        let swizzledSelector = #selector(UIViewController.fleet_presentingViewController)

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    fileprivate var fleet_property_presentingViewController: UIViewController? {
        get {
            return objc_getAssociatedObject(self, &presentingViewControllerAssociatedKey) as? UIViewController
        }
        set {
            objc_setAssociatedObject(self, &presentingViewControllerAssociatedKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }

    func fleet_presentingViewController() -> UIViewController? {
        return fleet_property_presentingViewController
    }
}
