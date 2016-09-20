import UIKit

extension UINavigationController {
    public override class func initialize() {
        struct Static {
            static var token: dispatch_once_t = 0
        }

        dispatch_once(&Static.token) {
            swizzlePushViewController()
            swizzlePopViewController()
            swizzlePopToViewController()
            swizzlePopToRootViewControllerAnimated()
        }
    }

    private class func swizzlePushViewController() {
        let originalSelector = #selector(UINavigationController.pushViewController(_:animated:))
        let swizzledSelector = #selector(UINavigationController.fleet_pushViewController(_:animated:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_pushViewController(viewController: UIViewController, animated: Bool) {
        var newViewControllers = self.viewControllers
        newViewControllers.append(viewController)
        self.setViewControllers(newViewControllers, animated: false)
        let _ = viewController.view
    }

    private class func swizzlePopViewController() {
        let originalSelector = #selector(UINavigationController.popViewControllerAnimated(_:))
        let swizzledSelector = #selector(UINavigationController.fleet_popViewControllerAnimated(_:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_popViewControllerAnimated(animated: Bool) -> UIViewController? {
        var newViewControllers = self.viewControllers
        let poppedViewController = newViewControllers.removeLast()
        self.setViewControllers(newViewControllers, animated: false)
        return poppedViewController
    }

    private class func swizzlePopToViewController() {
        let originalSelector = #selector(UINavigationController.popToViewController(_:animated:))
        let swizzledSelector = #selector(UINavigationController.fleet_popToViewController(_:animated:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_popToViewController(viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        return fleet_popToViewController(viewController, animated: false)
    }

    private class func swizzlePopToRootViewControllerAnimated() {
        let originalSelector = #selector(UINavigationController.popToRootViewControllerAnimated(_:))
        let swizzledSelector = #selector(UINavigationController.fleet_popToRootViewControllerAnimated(_:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_popToRootViewControllerAnimated(animated: Bool) -> [UIViewController]? {
        return fleet_popToRootViewControllerAnimated(false)
    }
}
