import XCTest
import Nimble
@testable import FleetUI

class FindTextActionSpec: XCTestCase {
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
        user.findText("KITTENS THO")
        expect(self.reporter.lastReportedMessage).to(equal("User could not find text \"KITTENS THO\": It does not seem to exist"))
    }
}
