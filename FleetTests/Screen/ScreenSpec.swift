import XCTest
import Nimble
@testable import Fleet
@testable import FleetTestApp

class ScreenSpec: XCTestCase {
    func test_topmostViewController_returnsTopmostViewController() {
        let window = UIWindow()
        let rootViewController = UIViewController()
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        expect(screen.topmostViewController).to(beIdenticalTo(rootViewController))

        let newTopmostViewController = UIViewController()
        rootViewController.present(newTopmostViewController, animated: true, completion: nil)

        expect(screen.topmostViewController).to(beIdenticalTo(newTopmostViewController))
    }

    func test_topmostViewController_whenNavigationControllerIsInWindowViewStack_returnsVisibleViewController() {
        let window = UIWindow()
        let rootNavigationController = UINavigationController()
        window.rootViewController = rootNavigationController
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        let pushedViewController = UIViewController()
        rootNavigationController.pushViewController(pushedViewController, animated: false)

        expect(screen.topmostViewController).to(beIdenticalTo(pushedViewController))
    }

    func test_topmostViewController_whenOnlyANavigationControllerIsInViewStack_returnsTheNavigationController() {
        let window = UIWindow()
        let rootNavigationController = UINavigationController()
        window.rootViewController = rootNavigationController
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        expect(screen.topmostViewController).to(beIdenticalTo(rootNavigationController))
    }

    func test_topmostViewController_whenTheTopViewControllerHasAPresentedViewController_returnsThatPresentedViewController() {
        let window = UIWindow()
        let rootNavigationController = UINavigationController()
        window.rootViewController = rootNavigationController
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        let rootViewController = UIViewController()
        rootNavigationController.pushViewController(rootViewController, animated: false)

        let viewControllerToPresent = UIViewController()
        rootViewController.present(viewControllerToPresent, animated: false, completion: nil)

        expect(screen.topmostViewController).to(beIdenticalTo(viewControllerToPresent))
    }

    func test_topmostViewController_whenAViewControllerIsModallyPresentedOverTopViewControllerInNavigationStack_returnsModallyPresentedController() {
        let window = UIWindow()
        let rootNavigationController = UINavigationController()
        window.rootViewController = rootNavigationController
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        let rootViewController = UIViewController()
        rootNavigationController.pushViewController(rootViewController, animated: false)

        let viewControllerToShow = UIViewController()
        rootViewController.show(viewControllerToShow, sender: nil)

        expect(screen.topmostViewController).to(beIdenticalTo(viewControllerToShow))
    }

    func test_presentedAlert_whenNoAlertIsPresented_returnsNil() {
        let storyboard = UIStoryboard.init(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let viewControllerThatPresentsAlerts = storyboard.instantiateViewController(withIdentifier: "SpottedTurtleViewController") as! SpottedTurtleViewController

        let window = UIWindow()
        window.rootViewController = viewControllerThatPresentsAlerts
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        expect(screen.presentedAlert).to(beNil())
    }

    func test_presentedAlert_whenAnAlertIsPresented_whenAlertIsAlertStyle_returnsTheAlert() {
        let storyboard = UIStoryboard.init(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let viewControllerThatPresentsAlerts = storyboard.instantiateViewController(withIdentifier: "SpottedTurtleViewController") as! SpottedTurtleViewController

        let window = UIWindow()
        window.rootViewController = viewControllerThatPresentsAlerts
        window.makeKeyAndVisible()

        try! viewControllerThatPresentsAlerts.alertButtonOne?.tap()

        let screen = Screen(forWindow: window)
        expect(screen.presentedAlert).toNot(beNil())
    }
}
