import XCTest
import Fleet
import Nimble
@testable import FleetTestApp

@MainActor
class UINavigationBar_FleetSpec: XCTestCase {
    var turtlesAndFriendsStoryboard: UIStoryboard!
    var boxTurtleViewController: BoxTurtleViewController!
    var navigationController: UINavigationController!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        turtlesAndFriendsStoryboard = UIStoryboard(name: "TurtlesAndFriendsStoryboard", bundle: nil)

        boxTurtleViewController = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController") as? BoxTurtleViewController

        navigationController = Fleet.setInAppWindowRootNavigation(boxTurtleViewController)
    }

    func test_tapTopItemWithTitle_rightItem_itemWithTitleExists_firesTheAction() {
        navigationController.navigationBar.tapTopItem(withTitle: "Dance")
        
        expect(self.boxTurtleViewController.informationLabel?.text).toEventually(equal("Box Turtle Dance Party!!!!!!"))
    }

    func test_tapTopItemWithTitle_leftItem_itemWithTitleExists_firesTheAction() {
        navigationController.navigationBar.tapTopItem(withTitle: "Stop")

        expect(self.boxTurtleViewController.informationLabel?.text).toEventually(equal("box turtle stop party..."))
    }

    func test_tapTopItemWithTitle_itemWithTitleDoesNotExist_throwsAnError() {
        expect { self.navigationController.navigationBar.tapTopItem(withTitle: "does not exist") }.to(
                raiseException(
                        named: "Fleet.NavBarError",
                        reason: "No item with title 'does not exist' found in nav bar.",
                        userInfo: nil,
                        closure: nil
                )
        )

        expect(self.boxTurtleViewController.informationLabel?.text).to(equal(""))
    }

    func test_tapTopItemWithTitle_titleOnBothSides_throwsAnErrorAndTapsNothing() {
        let navItem = boxTurtleViewController.navigationItem
        let counter = DuplicateTitleCounter()
        navItem.rightBarButtonItems = [UIBarButtonItem(title: "Same", style: .plain, target: counter, action: #selector(DuplicateTitleCounter.fire))]
        navItem.leftBarButtonItems = [UIBarButtonItem(title: "Same", style: .plain, target: counter, action: #selector(DuplicateTitleCounter.fire))]

        expect { self.navigationController.navigationBar.tapTopItem(withTitle: "Same") }.to(
            raiseException(
                named: "Fleet.NavBarError",
                reason: "2 items with title 'Same' found in nav bar; Fleet will not guess which to tap.",
                userInfo: nil,
                closure: nil
            )
        )

        expect(counter.count).to(equal(0))
    }
}

private final class DuplicateTitleCounter: NSObject {
    var count = 0
    @objc func fire() { count += 1 }
}
