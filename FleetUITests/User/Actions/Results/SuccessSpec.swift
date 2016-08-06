import XCTest
import Nimble
@testable import FleetUI

class SuccessSpec: XCTestCase {
    func test_succeeded_returnsTrue() {
        let subject = Success()
        expect(subject.succeeded).to(beTrue())
    }

    func test_resultDescription_returnsSuccess() {
        let subject = Success()
        expect(subject.resultDescription).to(equal("Succeeded"))
    }
}
