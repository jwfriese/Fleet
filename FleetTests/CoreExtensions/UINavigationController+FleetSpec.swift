import XCTest
import Fleet
import Nimble

@MainActor
class UINavigationController_FleetSpec: XCTestCase {
    fileprivate class TestViewController: UIViewController {
        var testViewDidLoadCallCount: UInt = 0
        var capturedNavigationController: UINavigationController?

        fileprivate override func viewDidLoad() {
            super.viewDidLoad()
            testViewDidLoadCallCount += 1
            capturedNavigationController = navigationController
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
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
        expect(controllerToPush.testViewDidLoadCallCount).to(equal(1))
    }

    func test_pushViewController_doesNotCausePushedViewControllerToLoadMultipleTimes() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerToPush = TestViewController()

        navigationController.pushViewController(controllerToPush, animated: true)

        expect(controllerToPush.testViewDidLoadCallCount).toEventuallyNot(beGreaterThan(1))
    }

    func test_pushViewController_doesNotLoadThePushedViewControllerUntilItWouldHaveANavigationController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerToPush = TestViewController()

        navigationController.pushViewController(controllerToPush, animated: true)

        expect(controllerToPush.capturedNavigationController).toEventuallyNot(beNil())
    }

    func test_popViewController_returnsPoppedViewController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerToPushThenPop = UIViewController()

        navigationController.pushViewController(controllerToPushThenPop, animated: true)
        let poppedViewController = navigationController.popViewController(animated: true)

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
        navigationController.popViewController(animated: true)

        expect(navigationController.topViewController).to(beIdenticalTo(root))
    }

    func test_popToViewController_immediatelySetsTheGivenViewControllerAsTopViewController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerOne = UIViewController()
        let controllerTwo = UIViewController()
        let controllerThree = UIViewController()

        navigationController.pushViewController(controllerOne, animated: false)
        navigationController.pushViewController(controllerTwo, animated: false)
        navigationController.pushViewController(controllerThree, animated: false)

        navigationController.popToViewController(controllerOne, animated: true)

        expect(navigationController.topViewController).to(beIdenticalTo(controllerOne))
    }

    func test_popToViewController_whenTheNavigationControllerIsInVisibleWindow_returnsThePoppedViewControllers() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerOne = UIViewController()
        let controllerTwo = UIViewController()
        let controllerThree = UIViewController()

        navigationController.pushViewController(controllerOne, animated: false)
        navigationController.pushViewController(controllerTwo, animated: false)
        navigationController.pushViewController(controllerThree, animated: false)

        let poppedControllers = navigationController.popToViewController(controllerOne, animated: true)

        if poppedControllers != nil {
            expect(poppedControllers!.count).to(equal(2))
            expect(poppedControllers![0]).to(beIdenticalTo(controllerTwo))
            expect(poppedControllers![1]).to(beIdenticalTo(controllerThree))
        } else {
            fail("Expected popToViewController(_:animated:) to return popped view controllers")
        }
    }

    func test_popToViewController_whenTheNavigationControllerNotInVisibleWindow_returnsPoppedControllers() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController

        let controllerOne = UIViewController()
        let controllerTwo = UIViewController()
        let controllerThree = UIViewController()

        navigationController.pushViewController(controllerOne, animated: false)
        navigationController.pushViewController(controllerTwo, animated: false)
        navigationController.pushViewController(controllerThree, animated: false)

        let poppedControllers = navigationController.popToViewController(controllerOne, animated: true)

        // Current UIKit returns the removed controllers even for an offscreen stack.
        expect(poppedControllers?.count).to(equal(2))
        expect(poppedControllers?[0]).to(beIdenticalTo(controllerTwo))
        expect(poppedControllers?[1]).to(beIdenticalTo(controllerThree))
        expect(navigationController.topViewController).to(beIdenticalTo(controllerOne))
    }

    func test_popToRootViewController_immediatelySetsTheRootViewControllerAsTheTopViewController() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerOne = UIViewController()
        let controllerTwo = UIViewController()

        navigationController.pushViewController(controllerOne, animated: true)
        navigationController.pushViewController(controllerTwo, animated: true)

        navigationController.popToRootViewController(animated: false)

        expect(navigationController.topViewController).to(beIdenticalTo(root))
    }

    func test_popToRootViewController_whenTheNavigationControllerIsInVisibleWindow_returnsThePoppedViewControllers() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let controllerOne = UIViewController()
        let controllerTwo = UIViewController()

        navigationController.pushViewController(controllerOne, animated: false)
        navigationController.pushViewController(controllerTwo, animated: false)

        let poppedControllers = navigationController.popToRootViewController(animated: true)

        if poppedControllers != nil {
            expect(poppedControllers!.count).to(equal(2))
            expect(poppedControllers![0]).to(beIdenticalTo(controllerOne))
            expect(poppedControllers![1]).to(beIdenticalTo(controllerTwo))
        } else {
            fail("Expected popToRootViewControllerAnimated(_:) to return popped view controllers")
        }
    }

    func test_popToRootViewController_whenTheNavigationControllerIsNotInVisibleWindow_returnsPoppedControllers() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController

        let controllerOne = UIViewController()
        let controllerTwo = UIViewController()

        navigationController.pushViewController(controllerOne, animated: false)
        navigationController.pushViewController(controllerTwo, animated: false)

        let poppedControllers = navigationController.popToRootViewController(animated: true)

        expect(poppedControllers?.count).to(equal(2))
        expect(poppedControllers?[0]).to(beIdenticalTo(controllerOne))
        expect(poppedControllers?[1]).to(beIdenticalTo(controllerTwo))
        expect(navigationController.topViewController).to(beIdenticalTo(root))
    }

    fileprivate class RecordingDelegate: NSObject, UINavigationControllerDelegate {
        var events: [String] = []
        func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
            events.append("willShow")
        }
        func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
            events.append("didShow")
        }
    }

    func test_pushViewController_notifiesDelegateInOrder() {
        let navigationController = UINavigationController(rootViewController: UIViewController())
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        let delegate = RecordingDelegate()
        navigationController.delegate = delegate

        navigationController.pushViewController(UIViewController(), animated: true)

        // UIKit delivers these callbacks after the call returns for a non-animated transition in
        // the hosted test window, so wait for them rather than asserting immediately.
        expect(delegate.events).toEventually(equal(["willShow", "didShow"]))
    }

    func test_popViewController_notifiesDelegateInOrder() {
        let navigationController = UINavigationController(rootViewController: UIViewController())
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        navigationController.pushViewController(UIViewController(), animated: false)
        let delegate = RecordingDelegate()
        navigationController.delegate = delegate

        navigationController.popViewController(animated: true)

        // UIKit delivers these callbacks after the call returns for a non-animated transition in
        // the hosted test window, so wait for them rather than asserting immediately.
        expect(delegate.events).toEventually(equal(["willShow", "didShow"]))
    }

    func test_popViewController_whenOnlyRootIsInStack_returnsNilAndPreservesRoot() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let popped = navigationController.popViewController(animated: false)

        expect(popped).to(beNil())
        expect(navigationController.viewControllers).to(equal([root]))
        expect(navigationController.topViewController).to(beIdenticalTo(root))
    }

    func test_popViewController_whenStackIsEmpty_returnsNil() {
        let navigationController = UINavigationController()

        let popped = navigationController.popViewController(animated: false)

        expect(popped).to(beNil())
        expect(navigationController.viewControllers).to(beEmpty())
    }

    func test_popToRootViewController_whenOnlyRootIsInStack_returnsNoControllersAndPreservesRoot() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let popped = navigationController.popToRootViewController(animated: false)

        expect(popped ?? []).to(beEmpty())
        expect(navigationController.viewControllers).to(equal([root]))
    }

    func test_popToRootViewController_whenStackIsEmpty_returnsNoControllers() {
        let navigationController = UINavigationController()

        let popped = navigationController.popToRootViewController(animated: false)

        expect(popped ?? []).to(beEmpty())
        expect(navigationController.viewControllers).to(beEmpty())
    }

    func test_popToViewController_whenAlreadyTop_returnsNoControllers() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        let popped = navigationController.popToViewController(root, animated: true)

        expect(popped ?? []).to(beEmpty())
        expect(navigationController.viewControllers).to(equal([root]))
    }

    func test_pushViewController_repeatedPushesBuildStackInOrder() {
        let root = UIViewController()
        let navigationController = UINavigationController(rootViewController: root)
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        let one = UIViewController()
        let two = UIViewController()

        navigationController.pushViewController(one, animated: true)
        navigationController.pushViewController(two, animated: true)

        expect(navigationController.viewControllers).to(equal([root, one, two]))
    }

    func test_navigationControllerWithSegueInViewDidLoad_segueHappensAndResultIsImmediatelyVisible() {
        let storyboard = UIStoryboard(name: "KittensStoryboard", bundle: nil)
        let viewController = UIViewController()
        try! storyboard.bind(viewController: viewController, toIdentifier: "KittenImage")

        let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController
        let window = UIWindow()
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        expect(navigationController?.visibleViewController).to(beIdenticalTo(viewController))
    }
}
