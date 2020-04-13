import UIKit

class HomeTabBarController: UITabBarController {
    var shouldSelectCallCount: Int = 0
    var didSelectCallCount: Int = 0

    var shouldSelectCallArgs: UIViewController?
    var didSelectCallArgs: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }
}

extension HomeTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        shouldSelectCallCount += 1
        shouldSelectCallArgs = viewController
        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        didSelectCallCount += 1
        didSelectCallArgs = viewController
    }
}
