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
    public static func setApplicationWindowRootViewController(_ viewController: UIViewController) {
        UIApplication.shared.keyWindow?.rootViewController = viewController
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
