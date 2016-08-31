import XCTest
import Nimble
@testable import Fleet
@testable import FleetTestApp

class ScreenSpec: XCTestCase {
    func test_topmostPresentedViewController_returnsTopmostPresentedViewController() {
        let window = UIWindow()
        let someOtherWindowRootViewController = UIViewController()
        window.rootViewController = someOtherWindowRootViewController
        window.makeKeyAndVisible()

        let screen = Screen(forWindow: window)

        expect(screen.topmostPresentedViewController).to(beIdenticalTo(someOtherWindowRootViewController))

        let newTopmostViewController = UIViewController()
        someOtherWindowRootViewController.presentViewController(newTopmostViewController, animated: true, completion: nil)

        expect(screen.topmostPresentedViewController).to(beIdenticalTo(newTopmostViewController))
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
