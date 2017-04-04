import XCTest
import Nimble

@testable import Fleet

class UIAlertAction_FleetSpec: XCTestCase {
    func test_handler_returnsTheHandlerUsedToInitializeAction() {
        var didFireHandler = false
        let alertAction = UIAlertAction(title: "title", style: .default) { action in
            didFireHandler = true
        }

        if let handler = alertAction.handler {
            handler(alertAction)
        }

        expect(didFireHandler).to(beTrue())
    }
}
