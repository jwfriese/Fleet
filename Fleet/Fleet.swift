import UIKit

public class Fleet {
    public static func getApplicationScreen() -> FLTScreen? {
        guard let window = UIApplication.shared.keyWindow else {
            Logger.logWarning("Cannot get application screen: UIApplication not set up with a key window.")
            return nil
        }

        return Screen(forWindow: window)
    }

    public static func getScreen(forWindow window: UIWindow) -> FLTScreen {
        return Screen(forWindow: window)
    }

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
