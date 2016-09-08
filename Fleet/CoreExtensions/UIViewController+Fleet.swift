import UIKit
import ObjectiveC

private var presentedViewControllerAssociatedKey: UInt = 0
private var presentingViewControllerAssociatedKey: UInt = 0

extension UIViewController {
    public override class func initialize() {
        struct Static {
            static var token: dispatch_once_t = 0
        }

        dispatch_once(&Static.token) {
            swizzlePresent()
            swizzleDismiss()
            swizzleShow()
            swizzlePresentedViewControllerProperty()
            swizzlePresentingViewControllerProperty()
        }
    }

    private class func swizzlePresent() {
        let originalSelector = #selector(UIViewController.presentViewController(_:animated:completion:))
        let swizzledSelector = #selector(UIViewController.fleet_presentViewController(_:animated:completion:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_presentViewController(viewController: UIViewController, animated: Bool, completion: (() -> ())?) {
        self.fleet_property_presentedViewController = viewController
        viewController.fleet_property_presentingViewController = self

        if let completion = completion {
            completion()
        }

        fleet_presentViewController(viewController, animated: animated, completion: nil)
    }

    private class func swizzleDismiss() {
        let originalSelector = #selector(UIViewController.dismissViewControllerAnimated(_:completion:))
        let swizzledSelector = #selector(UIViewController.fleet_dismissViewControllerAnimated(_:completion:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_dismissViewControllerAnimated(animated: Bool, completion: (() -> ())?) {
        let viewControllerToDismiss = self.fleet_property_presentedViewController

        self.fleet_property_presentedViewController = nil
        viewControllerToDismiss?.fleet_property_presentingViewController = nil

        if let completion = completion {
            completion()
        }

        fleet_dismissViewControllerAnimated(animated, completion: nil)
    }

    private class func swizzleShow() {
        let originalSelector = #selector(UIViewController.showViewController(_:sender:))
        let swizzledSelector = #selector(UIViewController.fleet_showViewController(_:sender:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_showViewController(viewController: UIViewController, sender: AnyObject?) {
        self.fleet_property_presentedViewController = viewController
        viewController.fleet_property_presentingViewController = self

        fleet_showViewController(viewController, sender: sender)
    }

    private class func swizzlePresentedViewControllerProperty() {
        let originalSelector = Selector("presentedViewController")
        let swizzledSelector = #selector(UIViewController.fleet_presentedViewController)

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    private var fleet_property_presentedViewController: UIViewController? {
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

    private class func swizzlePresentingViewControllerProperty() {
        let originalSelector = Selector("presentingViewController")
        let swizzledSelector = #selector(UIViewController.fleet_presentingViewController)

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    private var fleet_property_presentingViewController: UIViewController? {
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
