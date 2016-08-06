import XCTest
import FleetUI
import Nimble

class BoxTurtlePageTests: XCTestCase {
    var user: User!

    override func setUp() {
        super.setUp()

        continueAfterFailure = false
        let app = XCUIApplication()
        user = FleetUI.createUser(app, testCase: self)
        app.launch()
    }

    func testMakeThatTurtleDance() {
        user.tapButtonWithText("Box Turtle")
        user.tapButtonWithText("DANCE")
        user.findText("BOX TURTLE DANCE PARTY")
    }
}
