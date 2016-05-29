import UIKit

class TestNavigationController: UINavigationController {
    var lastPushAnimated: Bool!
    private weak var currentViewController: UIViewController!
    
    override func pushViewController(viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        self.lastPushAnimated = animated
        self.currentViewController = viewController
    }
    
    override var topViewController:UIViewController! {
        get {
            return currentViewController
        }
    }
}
