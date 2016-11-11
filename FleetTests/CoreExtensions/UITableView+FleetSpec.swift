import XCTest
import Fleet
import Nimble

@testable import FleetTestApp

class UITableView_FleetSpec: XCTestCase {
    func test_selectRow_whenACellExistsAtThatIndexPath_selectsTheCell() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateInitialViewController() as! BirdsViewController
        let _ = viewController.view
        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))

        expect(error).to(beNil())

        let presentedController = viewController.presentedViewController
        guard let alertController = presentedController as? UIAlertController else {
            fail("Expected tapping table view to have presented an alert controller")
            return
        }

        expect(alertController.message).to(equal("You selected Duck"))
    }

    func test_selectRow_whenNoCellExistsAtThatIndexPath_whenInvalidSectionInIndexPath_returnsAnError() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateInitialViewController() as! BirdsViewController
        let _ = viewController.view
        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 1))

        expect(error).toNot(beNil())
        expect(String(describing: error!)).to(equal("Fleet error: Invalid index path: Table view has no section 1 (section count in table view == 1)"))
    }

    func test_selectRow_whenNoCellExistsAtThatIndexPath_whenInvalidRowInIndexPath_returnsAnError() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateInitialViewController() as! BirdsViewController
        let _ = viewController.view
        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 100, section: 0))

        expect(error).toNot(beNil())
        expect(String(describing: error!)).to(equal("Fleet error: Invalid index path: Section 0 does not have row 100 (row count in section 0 == 21)"))
    }
}
