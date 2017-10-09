import XCTest
import UIKit
import Fleet
import Nimble

class CatchErrorSpec: XCTestCase {
    func test_swallowIfErrors_allowsCatchingOfFleetErrors() {
        let alert = UIAlertController(title: "title", message: "message", preferredStyle: .alert)
        Fleet.swallowAnyErrors {
            alert.tapAlertAction(withTitle: "Title That's Not There")
        }
    }
}
