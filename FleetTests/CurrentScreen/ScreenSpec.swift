import XCTest
import Nimble
@testable import Fleet
@testable import FleetTestApp

class ScreenSpec: XCTestCase {
    func test_topmostPresentedViewController_onApplicationScreen_returnsTopmostPresentedViewControllerOnApplicationViewStack() {
        let applicationRootViewController = UIViewController()
        Fleet.setApplicationWindowRootViewController(applicationRootViewController)

        let applicationScreen = Fleet.getApplicationScreen()
        expect(applicationScreen?.topmostPresentedViewController).to(beIdenticalTo(applicationRootViewController))

        let newTopmostViewController = UIViewController()
        applicationRootViewController.presentViewController(newTopmostViewController, animated: false, completion: nil)

        expect(applicationScreen?.topmostPresentedViewController).to(beIdenticalTo(newTopmostViewController))
    }

    func test_topmostPresentedViewController_onAnotherWindow_returnsTopmostPresentedViewController() {
        let window = UIWindow()
        let someOtherWindowRootViewController = UIViewController()
        window.rootViewController = someOtherWindowRootViewController
        window.makeKeyAndVisible()

        let screen = Fleet.getScreenForWindow(window)

        expect(screen.topmostPresentedViewController).to(beIdenticalTo(someOtherWindowRootViewController))

        let newTopmostViewController = UIViewController()
        someOtherWindowRootViewController.presentViewController(newTopmostViewController, animated: true, completion: nil)

        expect(screen.topmostPresentedViewController).to(beIdenticalTo(newTopmostViewController))
    }

    func test_presentedAlert_whenNoAlertIsPresented_returnsNil() {
        let storyboard = UIStoryboard.init(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let viewControllerThatPresentsAlerts = storyboard.instantiateViewControllerWithIdentifier("SpottedTurtleViewController") as! SpottedTurtleViewController
        Fleet.setApplicationWindowRootViewController(viewControllerThatPresentsAlerts)

        let applicationScreen = Fleet.getApplicationScreen()
        expect(applicationScreen!.presentedAlert).to(beNil())
    }

    func test_presentedAlert_whenAnAlertIsPresented_whenAlertIsAlertStyle_returnsTheAlert() {
        let storyboard = UIStoryboard.init(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let viewControllerThatPresentsAlerts = storyboard.instantiateViewControllerWithIdentifier("SpottedTurtleViewController") as! SpottedTurtleViewController
        Fleet.setApplicationWindowRootViewController(viewControllerThatPresentsAlerts)
        viewControllerThatPresentsAlerts.alertButtonOne?.tap()

        let applicationScreen = Fleet.getApplicationScreen()
        expect(applicationScreen!.presentedAlert).toNot(beNil())
    }
}
