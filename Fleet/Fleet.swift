import UIKit

public class Fleet {
    /**
     Provides a quick way of getting at the "main" application window in test.

     - returns:
     A `FLTScreen` instance wrapping the application's key window.
     */
    public static func getApplicationScreen() -> FLTScreen? {
        guard let window = UIApplication.shared.keyWindow else {
            Logger.logWarning("Cannot get application screen: UIApplication not set up with a key window.")
            return nil
        }

        return Screen(forWindow: window)
    }

    /**
     Wraps the given window in an instance of `FLTScreen` and returns it.

     - returns:
     A `FLTScreen` instance wrapping the given `UIWindow` instance.
     */
    public static func getScreen(forWindow window: UIWindow) -> FLTScreen {
        return Screen(forWindow: window)
    }

    /**
     Sets the given `UIViewController` as the main application window's root view controller.

     - note:
     This will kick off the given view controller's lifecycle.
     */
    public static func setAsAppWindowRoot(_ viewController: UIViewController) {
        UIApplication.shared.keyWindow?.rootViewController = viewController
        RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: Date(timeIntervalSinceNow: 1))
    }

    /**
     Sets up a `UINavigationController` as the root view controller of the main application window, and sets
     the the given `UIViewController` as the root view controller of that navigation controller.

     - note:
     This will kick off the given view controller's lifecycle.

     - returns:
     The `UINavigationController` that is now the root view controller of the main app window.
     */
    public static func setInAppWindowRootNavigation(_ viewController: UIViewController) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: viewController)
        UIApplication.shared.keyWindow?.rootViewController = navigationController
        RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: Date(timeIntervalSinceNow: 1))
        return navigationController
    }

    /**
     Note: The original file this func was taken from can be found in the Quick
     project (https://github.com/Quick/Quick)
     */
    internal static var currentTestBundle: Bundle? {
        return Bundle.allBundles.lazy
            .filter {
                $0.bundlePath.hasSuffix(".xctest")
            }
            .first
    }
}
