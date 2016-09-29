import UIKit

fileprivate var didSwizzle = false

extension UINavigationController {
    open override class func initialize() {
        super.initialize()
        if !didSwizzle {
            swizzlePushViewController()
            swizzlePopViewController()
            swizzlePopToViewController()
            swizzlePopToRootViewControllerAnimated()
            didSwizzle = true
        }
    }

    fileprivate class func swizzlePushViewController() {
        let originalSelector = #selector(UINavigationController.pushViewController(_:animated:))
        let swizzledSelector = #selector(UINavigationController.fleet_pushViewController(_:animated:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_pushViewController(_ viewController: UIViewController, animated: Bool) {
        var newViewControllers = self.viewControllers
        newViewControllers.append(viewController)
        self.setViewControllers(newViewControllers, animated: false)
        let _ = viewController.view
    }

    fileprivate class func swizzlePopViewController() {
        let originalSelector = #selector(UINavigationController.popViewController(animated:))
        let swizzledSelector = #selector(UINavigationController.fleet_popViewControllerAnimated(_:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_popViewControllerAnimated(_ animated: Bool) -> UIViewController? {
        var newViewControllers = self.viewControllers
        let poppedViewController = newViewControllers.removeLast()
        self.setViewControllers(newViewControllers, animated: false)
        return poppedViewController
    }

    fileprivate class func swizzlePopToViewController() {
        let originalSelector = #selector(UINavigationController.popToViewController(_:animated:))
        let swizzledSelector = #selector(UINavigationController.fleet_popToViewController(_:animated:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        return fleet_popToViewController(viewController, animated: false)
    }

    fileprivate class func swizzlePopToRootViewControllerAnimated() {
        let originalSelector = #selector(UINavigationController.popToRootViewController(animated:))
        let swizzledSelector = #selector(UINavigationController.fleet_popToRootViewControllerAnimated(_:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_popToRootViewControllerAnimated(_ animated: Bool) -> [UIViewController]? {
        return fleet_popToRootViewControllerAnimated(false)
    }
}
