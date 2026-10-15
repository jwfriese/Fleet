import UIKit

@MainActor
class Screen {
    fileprivate var window: UIWindow

    init(forWindow window: UIWindow) {
        self.window = window
    }
}

extension Screen: FLTScreen {
    var topmostContainer: UIViewController? {
        return Screen.endOfPresentationChain(window.rootViewController)
    }

    var topmostViewController: UIViewController? {
        var current = Screen.endOfPresentationChain(window.rootViewController)
        while let controller = current {
            let child: UIViewController?
            if let navigationController = controller as? UINavigationController {
                child = navigationController.topViewController
            } else if let tabBarController = controller as? UITabBarController {
                child = tabBarController.selectedViewController
            } else {
                child = nil
            }

            guard let child = child else { return controller }
            current = Screen.endOfPresentationChain(child)
        }
        return nil
    }

    private static func endOfPresentationChain(_ start: UIViewController?) -> UIViewController? {
        var current = start
        while let presented = current?.presentedViewController {
            current = presented
        }
        return current
    }

    var presentedAlert: UIAlertController? {
        get {
            return topmostViewController as? UIAlertController
        }
    }
}
