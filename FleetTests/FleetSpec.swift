import XCTest
import Nimble
import Fleet

#if os(iOS)
    @testable import FleetTestApp
#elseif os(tvOS)
    @testable import FleetTestApp_tvOS
#endif

class FleetSpec: XCTestCase {
    private var hostWindow: UIWindow?
    private var originalRootViewController: UIViewController?
    var applicationScreen: FLTScreen!
    var appWindowRootViewController: UIViewController!

    var otherWindowScreen: FLTScreen!
    var otherWindow: UIWindow!
    var otherWindowRootViewController: UIViewController!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        hostWindow = UIApplication.shared.keyWindow
        originalRootViewController = hostWindow?.rootViewController
        appWindowRootViewController = UIViewController()
        Fleet.setAsAppWindowRoot(appWindowRootViewController)
        applicationScreen = Fleet.getApplicationScreen()

        otherWindow = UIWindow()
        otherWindowRootViewController = UIViewController()
        otherWindow.rootViewController = otherWindowRootViewController
        otherWindowScreen = Fleet.getScreen(forWindow: otherWindow)
    }

    override func tearDown() {
        // Focus tests must finish editing before the next test replaces the root.
        hostWindow?.endEditing(true)
        if let root = hostWindow?.rootViewController, root.presentedViewController != nil {
            let dismissed = expectation(description: "Dismiss the test's presented controller")
            root.dismiss(animated: false) { dismissed.fulfill() }
            wait(for: [dismissed], timeout: 2)
        }
        hostWindow?.rootViewController = originalRootViewController
        hostWindow?.layoutIfNeeded()
        applicationScreen = nil
        appWindowRootViewController = nil
        otherWindowScreen = nil
        otherWindowRootViewController = nil
        otherWindow = nil
        originalRootViewController = nil
        hostWindow = nil
        super.tearDown()
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

    func test_replacingTheRoot_endsPreviousEditingAndHostsTheNewNavigationContent() {
        let previousController = UIViewController()
        #if os(tvOS)
        // tvOS text entry presents system UI asynchronously. Use a real, non-text
        // responder to verify the root handoff without interrupting that presentation.
        class FocusableView: UIView {
            override var canBecomeFirstResponder: Bool { return true }
        }
        let previousField = FocusableView()
        #else
        let previousField = UITextField()
        #endif
        Fleet.setAsAppWindowRoot(previousController)
        previousController.view.addSubview(previousField)
        expect(previousField.becomeFirstResponder()).to(beTrue())

        let storyboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "BoxTurtleViewController") as! BoxTurtleViewController
        let navigation = Fleet.setInAppWindowRootNavigation(controller)
        expect(previousField.isFirstResponder).to(beFalse())
        expect(navigation.topViewController).to(beIdenticalTo(controller))
        expect(controller.textField?.window).toNot(beNil())
        expect(controller.textField?.becomeFirstResponder()).to(beTrue())
    }
}
