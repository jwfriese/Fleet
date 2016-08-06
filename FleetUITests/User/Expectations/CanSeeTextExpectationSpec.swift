import XCTest
import Nimble
@testable import FleetUI

class CanSeeTextExpectationSpec: XCTestCase {
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

    func test_findText_whenNoTextExists_reportsError() {
        user.expectsTo(findText("KITTENS THO"))
        expect(self.reporter.lastReportedMessage).to(equal("User expected to find text \"KITTENS THO\", but it does not seem to exist"))
    }
}
