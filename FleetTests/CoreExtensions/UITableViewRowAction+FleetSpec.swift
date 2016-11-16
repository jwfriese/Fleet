import XCTest
import Nimble

@testable import Fleet

class UITableViewRowAction_FleetSpec: XCTestCase {
    func test_handler_returnsTheHandlerUsedToInitializeAction() {
        var didFireHandler = false

        let rowAction = UITableViewRowAction(style: .default, title: "turtle") { action, indexPath in
            didFireHandler = true
        }

        if let handler = rowAction.handler {
            handler(rowAction, IndexPath(row: 7, section: 14))
        }

        expect(didFireHandler).to(beTrue())
    }
}
