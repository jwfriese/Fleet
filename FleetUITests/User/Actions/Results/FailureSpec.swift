import XCTest
import Nimble
@testable import FleetUI

class FailureSpec: XCTestCase {
    func test_succeeded_returnsFalse() {
        let subject = Failure("")
        expect(subject.succeeded).to(beFalse())
    }

    func test_resultDescription_returnsMessageUsedToInitializeFailure() {
        let subject = Failure("failure message")
        expect(subject.resultDescription).to(equal("failure message"))
    }
}
