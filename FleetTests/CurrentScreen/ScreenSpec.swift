import XCTest
import Nimble
@testable import Fleet
@testable import FleetTestApp

class ScreenSpec: XCTestCase {
    func test_topmostPresentedViewController_returnsTopmostPresentedViewController() {
        let window = UIWindow()
        let rootViewController = UIViewController()
        window.rootViewController = rootViewController
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        expect(screen.topmostViewController).to(beIdenticalTo(rootViewController))

        let newTopmostViewController = UIViewController()
        rootViewController.presentViewController(newTopmostViewController, animated: true, completion: nil)

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

    func test_presentedAlert_whenNoAlertIsPresented_returnsNil() {
        let storyboard = UIStoryboard.init(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let viewControllerThatPresentsAlerts = storyboard.instantiateViewControllerWithIdentifier("SpottedTurtleViewController") as! SpottedTurtleViewController

        let window = UIWindow()
        window.rootViewController = viewControllerThatPresentsAlerts
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        expect(screen.presentedAlert).to(beNil())
    }

    func test_presentedAlert_whenAnAlertIsPresented_whenAlertIsAlertStyle_returnsTheAlert() {
        let storyboard = UIStoryboard.init(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let viewControllerThatPresentsAlerts = storyboard.instantiateViewControllerWithIdentifier("SpottedTurtleViewController") as! SpottedTurtleViewController

        let window = UIWindow()
        window.rootViewController = viewControllerThatPresentsAlerts
        window.makeKeyAndVisible()

        viewControllerThatPresentsAlerts.alertButtonOne?.tap()

        let screen = Screen(forWindow: window)
        expect(screen.presentedAlert).toNot(beNil())
    }
}
