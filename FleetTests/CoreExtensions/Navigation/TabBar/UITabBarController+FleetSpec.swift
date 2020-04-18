import XCTest
import Fleet
import Nimble

@testable import FleetTestApp

class UITabBarController_FleetSpec: XCTestCase {
    var turtlesAndFriendsStoryboard: UIStoryboard!
    var subject: HomeTabBarController!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        turtlesAndFriendsStoryboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)

        subject = (turtlesAndFriendsStoryboard.instantiateInitialViewController() as! HomeTabBarController)

        Fleet.setAsAppWindowRoot(subject)
    }

    func test_selectTabWithLabelText_firesDelegateCallMethodsWithCorrectArgs() {
        subject.selectTab(withLabel: "Fruit")

        expect(self.subject.shouldSelectCallCount).to(equal(1))
        expect(self.subject.didSelectCallCount).to(equal(1))
        expect(self.subject.shouldSelectCallArgs).to(beAKindOf(FruitViewController.self))
        expect(self.subject.didSelectCallArgs).to(beAKindOf(FruitViewController.self))
    }

    func test_selectTabWithLabelText_switchesToTheViewControllerOfTheSelectedTab() {
        subject.selectTab(withLabel: "Fruit")

        let presentedController = Fleet.getApplicationScreen()?.topmostViewController
        expect(presentedController).toEventually(beAKindOf(HomeTabBarController.self))

        let tabBarController = presentedController as! HomeTabBarController

        expect(tabBarController.selectedViewController).toEventually(beAKindOf(FruitViewController.self))

        subject.selectTab(withLabel: "Animals")

        let nextPresentedController = Fleet.getApplicationScreen()?.topmostViewController
        expect(nextPresentedController).toEventually(beAKindOf(HomeTabBarController.self))

        let nextTabBarController = nextPresentedController as! HomeTabBarController

        expect(nextTabBarController.selectedViewController).toEventually(beAKindOf(UINavigationController.self))
    }
}
