import UIKit

extension UINavigationController {
    @objc class func swizzlePushViewController() {
        Fleet.swizzle(
            originalSelector: #selector(UINavigationController.pushViewController(_:animated:)),
            swizzledSelector: #selector(UINavigationController.fleet_pushViewController(_:animated:)),
            forClass: self
        )
    }

    @objc func fleet_pushViewController(_ viewController: UIViewController, animated: Bool) {
        var newViewControllers = self.viewControllers
        newViewControllers.append(viewController)
        self.setViewControllers(newViewControllers, animated: false)
        let _ = viewController.view
    }

    @objc class func swizzlePopViewController() {
        Fleet.swizzle(
            originalSelector: #selector(UINavigationController.popViewController(animated:)),
            swizzledSelector: #selector(UINavigationController.fleet_popViewControllerAnimated(_:)),
            forClass: self
        )
    }

    @objc func fleet_popViewControllerAnimated(_ animated: Bool) -> UIViewController? {
        var newViewControllers = self.viewControllers
        let poppedViewController = newViewControllers.removeLast()
        self.setViewControllers(newViewControllers, animated: false)
        return poppedViewController
    }

    @objc class func swizzlePopToViewController() {
        Fleet.swizzle(
            originalSelector: #selector(UINavigationController.popToViewController(_:animated:)),
            swizzledSelector: #selector(UINavigationController.fleet_popToViewController(_:animated:)),
            forClass: self
        )
    }

    @objc func fleet_popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        return fleet_popToViewController(viewController, animated: false)
    }

    @objc class func swizzlePopToRootViewControllerAnimated() {
        Fleet.swizzle(
            originalSelector: #selector(UINavigationController.popToRootViewController(animated:)),
            swizzledSelector: #selector(UINavigationController.fleet_popToRootViewControllerAnimated(_:)),
            forClass: self
        )
    }

    @objc func fleet_popToRootViewControllerAnimated(_ animated: Bool) -> [UIViewController]? {
        return fleet_popToRootViewControllerAnimated(false)
    }
}
