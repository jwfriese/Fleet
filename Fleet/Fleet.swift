import UIKit

public class Fleet {
    public static func getApplicationScreen() -> FLTScreen? {
        guard let window = UIApplication.sharedApplication().keyWindow else {
            Logger.logWarning("Cannot get application screen: UIApplication not set up with a key window.")
            return nil
        }

        return Screen(forWindow: window)
    }

    public static func getScreenForWindow(window: UIWindow) -> FLTScreen {
        return Screen(forWindow: window)
    }

    public static func setApplicationWindowRootViewController(viewController: UIViewController) {
        UIApplication.sharedApplication().keyWindow?.rootViewController = viewController
    }

    /**
     Note: The original file this func was taken from can be found in the Quick
     project (https://github.com/Quick/Quick)
     */
    internal static var currentTestBundle: NSBundle? {
        return NSBundle.allBundles().lazy
            .filter {
                $0.bundlePath.hasSuffix(".xctest")
            }
            .first
    }

}
