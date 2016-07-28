import XCTest

class BoxTurtlePageTests: XCTestCase {
    
    override func setUp() {
        super.setUp()

        continueAfterFailure = false
        XCUIApplication().launch()
    }

    func testMakeThatTurtleDance() {
        let app = XCUIApplication()
        app.buttons["Box Turtle"].tap()
        app.navigationBars["FleetTestApp.BoxTurtleView"].buttons["DANCE"].tap()
        XCTAssertTrue(app.staticTexts["BOX TURTLE DANCE PARTY"].exists)
        XCTAssertFalse(app.staticTexts["BOX TURTLE FRANCE PARTY?"].exists)
    }

}
