import XCTest
import Nimble
import Fleet

class FleetErrorSpec: XCTestCase {
    func test_canBeUsedToIntializeAString() {
        let error = FleetError(message: "turtle error message")
        let errorString = String(describing: error)
        expect(errorString).to(equal("Fleet error: turtle error message"))
    }

    func test_isCustomStringConvertible() {
        let error = FleetError(message: "turtle error message")
        let errorString = error.description
        expect(errorString).to(equal("Fleet error: turtle error message"))
    }

    func test_isDebugStringConvertible() {
        let error = FleetError(message: "turtle error message")
        let errorString = error.debugDescription
        expect(errorString).to(equal("Fleet error: turtle error message"))
    }
}
