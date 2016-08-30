import Foundation

public class Fleet {
    public static func getCurrentScreen() -> FLTScreen? {
        return Screen()
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
