import XCTest
import Nimble
import Fleet

class FleetSpec: XCTestCase {
    var applicationScreen: FLTScreen!
    var appWindowRootViewController: UIViewController!

    var otherWindowScreen: FLTScreen!
    var otherWindow: UIWindow!
    var otherWindowRootViewController: UIViewController!

    override func setUp() {
        super.setUp()

        appWindowRootViewController = UIViewController()
        Fleet.setApplicationWindowRootViewController(appWindowRootViewController)
        applicationScreen = Fleet.getApplicationScreen()

        otherWindow = UIWindow()
        otherWindowRootViewController = UIViewController()
        otherWindow.rootViewController = otherWindowRootViewController
        otherWindowScreen = Fleet.getScreenForWindow(otherWindow)
    }

    func test_getApplicationWindow_returnsScreenAttachedToApplicationWindow() {
        expect(self.applicationScreen.topmostViewController).to(beIdenticalTo(appWindowRootViewController))
    }

    func test_getScreenForWindow_returnsScreenAttachedToGivenWindow() {
        expect(self.otherWindowScreen.topmostViewController).to(beIdenticalTo(otherWindowRootViewController))
    }
}
