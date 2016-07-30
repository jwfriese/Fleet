import XCTest
import FleetUI
import Nimble

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
        expect(self.user.canSeeText("BOX TURTLE DANCE PARTY")).to(beTrue())
        expect(self.user.canSeeText("BOX TURTLE FRANCE PARTY?")).to(beFalse())
    }
}
