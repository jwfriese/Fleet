import XCTest
import FleetUI

class BoxTurtlePageTests: XCTestCase {
    var user: User!
    
    override func setUp() {
        super.setUp()

        continueAfterFailure = false
        let app = XCUIApplication()
        user = User(xcApp: app)
        app.launch()
    }

    func testMakeThatTurtleDance() {
        user.tapButtonWithText("Box Turtle")
        user.tapButtonWithText("DANCE")
        XCTAssertTrue(user.canSeeText("BOX TURTLE DANCE PARTY"))
        XCTAssertFalse(user.canSeeText("BOX TURTLE FRANCE PARTY?"))
    }
}
