import XCTest
import Nimble
@testable import FleetUI

class ErrorSpec: XCTestCase {
    func test_succeeded_returnsFalse() {
        let subject = Error("")
        expect(subject.succeeded).to(beFalse())
    }

    func test_resultDescription_returnsMessageUsedToInitializeError() {
        let subject = Error("error message")
        expect(subject.resultDescription).to(equal("Errored: error message"))
    }
}
