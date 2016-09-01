class Screen {
    private var window: UIWindow

    init(forWindow window: UIWindow) {
        self.window = window
    }
}

extension Screen: FLTScreen {
    var topmostPresentedViewController: UIViewController? {
        return topmostViewControllerRecursive(window.rootViewController)
    }

    private func topmostViewControllerRecursive(rootViewController: UIViewController?) -> UIViewController? {
        if let navigationController = rootViewController as? UINavigationController {
            return navigationController.visibleViewController
        }

        if let presentedViewController = rootViewController?.presentedViewController {
            return topmostViewControllerRecursive(presentedViewController)
        }

        return rootViewController
    }

    var presentedAlert: UIAlertController? {
        get {
            return topmostPresentedViewController as? UIAlertController
        }
    }
}
