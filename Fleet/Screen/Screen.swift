class Screen {
    fileprivate var window: UIWindow

    init(forWindow window: UIWindow) {
        self.window = window
    }
}

extension Screen: FLTScreen {
    var topmostViewController: UIViewController? {
        return topmostViewControllerRecursive(window.rootViewController)
    }

    fileprivate func topmostViewControllerRecursive(_ rootViewController: UIViewController?) -> UIViewController? {
        if let navigationController = rootViewController as? UINavigationController {
            guard let topViewController = navigationController.topViewController else {
                return navigationController
            }

            guard let presentedViewController = topViewController.presentedViewController else {
                return topViewController
            }

            return presentedViewController
        }

        if let presentedViewController = rootViewController?.presentedViewController {
            return topmostViewControllerRecursive(presentedViewController)
        }

        return rootViewController
    }

    var presentedAlert: UIAlertController? {
        get {
            return topmostViewController as? UIAlertController
        }
    }
}
