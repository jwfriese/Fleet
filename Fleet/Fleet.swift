import Foundation

public class Fleet {
    public static func getCurrentScreen() -> FLTScreen? {
        return Screen()
    }
    
    public static func swapWindowRootViewController(viewController: UIViewController) {
        UIApplication.sharedApplication().keyWindow?.rootViewController = viewController
    }
}
