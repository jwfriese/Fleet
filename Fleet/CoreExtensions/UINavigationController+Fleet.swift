import UIKit

extension UINavigationController {
    @objc class func swizzlePushViewController() {
        let originalSelector = #selector(UINavigationController.pushViewController(_:animated:))
        let swizzledSelector = #selector(UINavigationController.fleet_pushViewController(_:animated:))

        guard let originalMethod = class_getInstanceMethod(self, originalSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UINavigationController.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }
        guard let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UINavigationController.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func fleet_pushViewController(_ viewController: UIViewController, animated: Bool) {
        var newViewControllers = self.viewControllers
        newViewControllers.append(viewController)
        self.setViewControllers(newViewControllers, animated: false)
        let _ = viewController.view
    }

    @objc class func swizzlePopViewController() {
        let originalSelector = #selector(UINavigationController.popViewController(animated:))
        let swizzledSelector = #selector(UINavigationController.fleet_popViewControllerAnimated(_:))

        guard let originalMethod = class_getInstanceMethod(self, originalSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UINavigationController.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }
        guard let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UINavigationController.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func fleet_popViewControllerAnimated(_ animated: Bool) -> UIViewController? {
        var newViewControllers = self.viewControllers
        let poppedViewController = newViewControllers.removeLast()
        self.setViewControllers(newViewControllers, animated: false)
        return poppedViewController
    }

    @objc class func swizzlePopToViewController() {
        let originalSelector = #selector(UINavigationController.popToViewController(_:animated:))
        let swizzledSelector = #selector(UINavigationController.fleet_popToViewController(_:animated:))

        guard let originalMethod = class_getInstanceMethod(self, originalSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UINavigationController.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }
        guard let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UINavigationController.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func fleet_popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        return fleet_popToViewController(viewController, animated: false)
    }

    @objc class func swizzlePopToRootViewControllerAnimated() {
        let originalSelector = #selector(UINavigationController.popToRootViewController(animated:))
        let swizzledSelector = #selector(UINavigationController.fleet_popToRootViewControllerAnimated(_:))

        guard let originalMethod = class_getInstanceMethod(self, originalSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UINavigationController.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }
        guard let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UINavigationController.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func fleet_popToRootViewControllerAnimated(_ animated: Bool) -> [UIViewController]? {
        return fleet_popToRootViewControllerAnimated(false)
    }
}
