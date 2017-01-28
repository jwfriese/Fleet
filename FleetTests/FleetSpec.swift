import XCTest
import Nimble
import Fleet

@testable import FleetTestApp

class FleetSpec: XCTestCase {
    var applicationScreen: FLTScreen!
    var appWindowRootViewController: UIViewController!

    var otherWindowScreen: FLTScreen!
    var otherWindow: UIWindow!
    var otherWindowRootViewController: UIViewController!

    override func setUp() {
        super.setUp()

        appWindowRootViewController = UIViewController()
        Fleet.setAsAppWindowRoot(appWindowRootViewController)
        applicationScreen = Fleet.getApplicationScreen()

        otherWindow = UIWindow()
        otherWindowRootViewController = UIViewController()
        otherWindow.rootViewController = otherWindowRootViewController
        otherWindowScreen = Fleet.getScreen(forWindow: otherWindow)
    }

    func test_getApplicationWindow_returnsScreenAttachedToApplicationWindow() {
        expect(self.applicationScreen.topmostViewController).to(beIdenticalTo(appWindowRootViewController))
    }

    func test_getScreenForWindow_returnsScreenAttachedToGivenWindow() {
        expect(self.otherWindowScreen.topmostViewController).to(beIdenticalTo(otherWindowRootViewController))
    }

    func test_setAsAppWindowRoot_viewsInWindowCanBecomeFirstResponderImmediately() {
        let viewController = UIViewController()
        let textField = UITextField()
        Fleet.setAsAppWindowRoot(viewController)
        viewController.view.addSubview(textField)
        expect(textField.becomeFirstResponder()).to(beTrue())
    }

    func test_setAsAppWindowRoot_viewsFromIBOutletsCanBecomeFirstResponderImmediately() {
        let storyboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BoxTurtleViewController") as! BoxTurtleViewController
        Fleet.setAsAppWindowRoot(viewController)
        guard let textField = viewController.textField else {
            fail("Could not instantiate text field from IBOutlet after setting as root view controller")
            return
        }

        expect(textField.becomeFirstResponder()).to(beTrue())
    }

    func test_setAsAppWindowRoot_viewsFromIBOutletsCanBecomeFirstResponderImmediatelyEvenInNavigationControllers() {
        let storyboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BoxTurtleViewController") as! BoxTurtleViewController
        let navigationController = UINavigationController(rootViewController: viewController)
        Fleet.setAsAppWindowRoot(navigationController)
        guard let textField = viewController.textField else {
            fail("Could not instantiate text field from IBOutlet after setting as root view controller")
            return
        }

        expect(textField.canBecomeFirstResponder).to(beTrue())
        expect(textField.becomeFirstResponder()).to(beTrue())
    }

    func test_setInAppWindowRootNavigation_viewsFromIBOutletsCanBecomeFirstResponderImmediately() {
        let storyboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BoxTurtleViewController") as! BoxTurtleViewController
        _ = Fleet.setInAppWindowRootNavigation(viewController)
        guard let textField = viewController.textField else {
            fail("Could not instantiate text field from IBOutlet after setting as root view controller")
            return
        }

        expect(textField.canBecomeFirstResponder).to(beTrue())
        expect(textField.becomeFirstResponder()).to(beTrue())
    }
}
