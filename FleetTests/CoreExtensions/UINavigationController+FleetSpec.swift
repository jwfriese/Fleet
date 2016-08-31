import XCTest
import Fleet
import Nimble

class UINavigationController_FleetSpec: XCTestCase {
    private class TestViewController: UIViewController {
        var viewDidLoadCallCount: UInt = 0
        private override func viewDidLoad() {
            super.viewDidLoad()
            viewDidLoadCallCount += 1
        }
    }

    func test_pushViewController_immediatelySetsTheViewControllerAsTheTopController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerToPush = UIViewController()

        navigationController.pushViewController(controllerToPush, animated: true)

        expect(navigationController.topViewController).to(beIdenticalTo(controllerToPush))
    }

    func test_pushViewController_immediatelyLoadsThePushedViewController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerToPush = TestViewController()

        navigationController.pushViewController(controllerToPush, animated: true)
        expect(controllerToPush.viewDidLoadCallCount).to(equal(1))
    }

    func test_pushViewController_doesNotCausePushedViewControllerToLoadMultipleTimes() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerToPush = TestViewController()

        navigationController.pushViewController(controllerToPush, animated: true)

        expect(controllerToPush.viewDidLoadCallCount).toNotEventually(beGreaterThan(1))
    }

    func test_popViewController_returnsPoppedViewController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerToPushThenPop = UIViewController()

        navigationController.pushViewController(controllerToPushThenPop, animated: true)
        let poppedViewController = navigationController.popViewControllerAnimated(true)

        expect(poppedViewController).to(beIdenticalTo(controllerToPushThenPop))
    }

    func test_popViewController_immediatelySetsTheNextViewControllerInStackAsTopViewController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerToPushThenPop = UIViewController()

        navigationController.pushViewController(controllerToPushThenPop, animated: true)
        navigationController.popViewControllerAnimated(true)

        expect(navigationController.topViewController).to(beIdenticalTo(root))
    }

    func test_navigationControllerWithSegueInViewDidLoad_segueHappensAndResultIsImmediatelyVisible() {
        let storyboard = UIStoryboard(name: "KittensStoryboard", bundle: nil)
        let viewController = UIViewController()
        try! storyboard.bindViewController(viewController, toIdentifier: "KittenImage")

        let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        expect(navigationController?.visibleViewController).to(beIdenticalTo(viewController))
    }
}
