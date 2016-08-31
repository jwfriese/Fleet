class Screen {
    private var window: UIWindow

    init(forWindow window: UIWindow) {
        self.window = window
    }
}

extension Screen: FLTScreen {
    var topmostPresentedViewController: UIViewController? {
        let rootViewController = window.rootViewController
        if var viewController = rootViewController {
            while viewController.presentedViewController != nil {
                viewController = viewController.presentedViewController!
            }

            return viewController
        }

        return nil
    }

    var presentedAlert: UIAlertController? {
        get {
            return topmostPresentedViewController as? UIAlertController
        }
    }
}
