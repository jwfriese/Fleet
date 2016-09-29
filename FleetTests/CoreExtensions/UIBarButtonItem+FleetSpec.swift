import XCTest
import Fleet
import Nimble

@testable import FleetTestApp

class UIBarButtonItem_FleetSpec: XCTestCase {
    var turtlesAndFriendsStoryboard: UIStoryboard!

    override func setUp() {
        super.setUp()
        turtlesAndFriendsStoryboard = UIStoryboard.init(name: "TurtlesAndFriendsStoryboard", bundle: nil)
    }

    func test_tap_directlyOnBarButtonItem_whenEnabled_performsAction() {
        let boxTurtleViewController = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController") as? BoxTurtleViewController
        let _ = boxTurtleViewController?.view

        boxTurtleViewController?.rightBarButtonItem?.tap()

        expect(boxTurtleViewController?.informationLabel?.text).to(equal("BOX TURTLE DANCE PARTY"))
    }

    func test_tap_directlyOnBarButtonItem_whenNotEnabled_doesNotPerformAction() {
        let boxTurtleViewController = turtlesAndFriendsStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController") as? BoxTurtleViewController
        let _ = boxTurtleViewController?.view

        boxTurtleViewController?.rightBarButtonItem?.isEnabled = false

        boxTurtleViewController?.rightBarButtonItem?.tap()

        expect(boxTurtleViewController?.informationLabel?.text).to(equal(""))
    }
}
