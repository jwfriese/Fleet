import XCTest
@testable import FleetUI

class FakeReporter: Reporter {
    var lastReportedMessage: String?
    
    func reportError(errorMessage: String, testCase: XCTestCase) {
        lastReportedMessage = errorMessage
    }
}