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
        let app = XCUIApplication()
        user.tapButtonWithText("Box Turtle")
        user.tapButtonWithText("DANCE")
        XCTAssertTrue(app.staticTexts["BOX TURTLE DANCE PARTY"].exists)
        XCTAssertFalse(app.staticTexts["BOX TURTLE FRANCE PARTY?"].exists)
    }

}
