import XCTest
import Nimble
@testable import FleetUI

class TapButtonActionSpec: XCTestCase {
    var user: User!
    var reporter: FakeReporter!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        let app = XCUIApplication()
        reporter = FakeReporter()
        user = User(xcApp: app, testCase: self, reporter: reporter)
        app.launch()
    }

    func testTapButton_whenNoMatchingButtonExists_reportsError() {
        user.tapButtonWithText("KITTENS THO")
        expect(self.reporter.lastReportedMessage).to(equal("User could not find button with text \"KITTENS THO\": It does not seem to exist"))
    }
}
