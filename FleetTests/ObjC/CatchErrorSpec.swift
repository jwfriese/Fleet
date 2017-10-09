import XCTest
import UIKit
import Fleet
import Nimble

class CatchErrorSpec: XCTestCase {
    func test_catchError_allowsCatchingOfFleetErrors() {
        let alert = UIAlertController(title: "title", message: "message", preferredStyle: .alert)
        Fleet.do {
            alert.tapAlertAction(withTitle: "Title That's Not There")
        }
    }
}
