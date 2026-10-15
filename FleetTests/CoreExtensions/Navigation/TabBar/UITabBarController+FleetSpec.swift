import XCTest
import Fleet
import Nimble

#if os(iOS)
    @testable import FleetTestApp
#elseif os(tvOS)
    @testable import FleetTestApp_tvOS
#endif

@MainActor
class UITabBarController_FleetSpec: XCTestCase {
    var turtlesAndFriendsStoryboard: UIStoryboard!
    var subject: HomeTabBarController!

    override func setUp() async throws {
        try await super.setUp()
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

        let presentedController = Fleet.getApplicationScreen()?.topmostContainer
        expect(presentedController).toEventually(beAKindOf(HomeTabBarController.self))

        let tabBarController = presentedController as! HomeTabBarController

        expect(tabBarController.selectedViewController).toEventually(beAKindOf(FruitViewController.self))

        subject.selectTab(withLabel: "Animals")

        let nextPresentedController = Fleet.getApplicationScreen()?.topmostContainer
        expect(nextPresentedController).toEventually(beAKindOf(HomeTabBarController.self))

        let nextTabBarController = nextPresentedController as! HomeTabBarController

        expect(nextTabBarController.selectedViewController).toEventually(beAKindOf(UINavigationController.self))
    }

    func test_selectTabAtIndex_whenIndexIsNegative_doesNothing() {
        let original = subject.selectedViewController

        subject.selectTab(atIndex: -1)

        expect(self.subject.shouldSelectCallCount).to(equal(0))
        expect(self.subject.didSelectCallCount).to(equal(0))
        expect(self.subject.selectedViewController).to(beIdenticalTo(original))
    }

    func test_selectTabAtIndex_whenIndexIsOutOfRange_doesNothing() {
        let original = subject.selectedViewController

        subject.selectTab(atIndex: 1000)

        expect(self.subject.shouldSelectCallCount).to(equal(0))
        expect(self.subject.didSelectCallCount).to(equal(0))
        expect(self.subject.selectedViewController).to(beIdenticalTo(original))
    }
}
