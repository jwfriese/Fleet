class Screen {
    private var window: UIWindow

    init(forWindow window: UIWindow) {
        self.window = window
    }
}

extension Screen: FLTScreen {
    var topmostPresentedViewController: UIViewController? {
        let rootViewController = UIApplication.sharedApplication().keyWindow?.rootViewController
        if var viewController = rootViewController {
            while viewController.presentedViewController != nil {
                viewController = viewController.presentedViewController!
            }

            return viewController
        }

        Logger.logWarning("Unable to locate test application's root view controller. Make sure there is a key window even in test runs.")
        return nil
    }

    var presentedAlert: UIAlertController? {
        get {
            return topmostPresentedViewController as? UIAlertController
        }
    }
}
