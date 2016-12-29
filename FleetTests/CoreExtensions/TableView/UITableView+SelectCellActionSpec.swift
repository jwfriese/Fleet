import XCTest
import Fleet
import Nimble

@testable import FleetTestApp

class UITableView_SelectCellActionSpec: XCTestCase {
    func test_selectCellAction_whenTheActionExists_performsTheAction() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        let error = viewController.birdsTableView?.selectCellAction(withTitle: "Two", at: IndexPath(row: 10, section: 0))
        expect(error).to(beNil())
        expect((viewController.presentedViewController as? UIAlertController)).toEventuallyNot(beNil())
        expect((viewController.presentedViewController as? UIAlertController)?.message).toEventually(equal("Two tapped at row 10"))
    }

    func test_selectCellAction_whenTheActionExists_callsWillBeginEditingOnDelegate() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        let _ = viewController.birdsTableView?.selectCellAction(withTitle: "Two", at: IndexPath(row: 10, section: 0))
        expect(viewController.willBeginEditingRowCallArgs.count).to(equal(1))
        expect(viewController.willBeginEditingRowCallArgs.first).to(equal(IndexPath(row: 10, section: 0)))
    }

    func test_selectCellAction_whenTheActionExists_callsDidEndEditingOnDelegate() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        let _ = viewController.birdsTableView?.selectCellAction(withTitle: "Two", at: IndexPath(row: 10, section: 0))
        expect(viewController.didEndEditingRowCallArgs.count).to(equal(1))
        expect(viewController.didEndEditingRowCallArgs.first).to(equal(IndexPath(row: 10, section: 0)))
    }

    func test_selectCellAction_whenTheActionDoesNotExist_returnsAnError() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        let error = viewController.birdsTableView?.selectCellAction(withTitle: "Four", at: IndexPath(row: 10, section: 0))
        expect(String(describing: error!)).to(equal("Fleet error: Could not find edit action with title 'Four' at row 10 in section 0"))
    }

    func test_selectCellAction_whenNoCellExistsAtThatIndexPath_whenInvalidSectionInIndexPath_returnsAnError() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        let error = viewController.birdsTableView?.selectCellAction(withTitle: "One", at: IndexPath(row: 1, section: 1))

        expect(error).toNot(beNil())
        expect(String(describing: error!)).to(equal("Fleet error: Invalid index path: Table view has no section 1 (section count in table view == 1)"))
    }

    func test_selectCellAction_whenNoCellExistsAtThatIndexPath_whenInvalidRowInIndexPath_returnsAnError() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        let error = viewController.birdsTableView?.selectCellAction(withTitle: "One", at: IndexPath(row: 100, section: 0))

        expect(error).toNot(beNil())
        expect(String(describing: error!)).to(equal("Fleet error: Invalid index path: Section 0 does not have row 100 (row count in section 0 == 21)"))
    }

    func test_selectCellAction_whenDataSourceSaysThatIndexPathCannotBeEdited_returnsAnError() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        // The fourth row in the table view is not editable
        let errorOpt = viewController.birdsTableView?.selectCellAction(withTitle: "One", at: IndexPath(row: 3, section: 0))

        guard let error = errorOpt else {
            fail("Failed to return any FleetError")
            return
        }

        expect(String(describing: error)).to(equal("Fleet error: Editing of row 3 in section 0 is not allowed by the table view's data source"))
    }

    func test_selectCellAction_whenTableViewDoesNotHaveDataSource_returnsAnError() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        viewController.birdsTableView?.dataSource = nil

        let error = viewController.birdsTableView?.selectCellAction(withTitle: "Two", at: IndexPath(row: 10, section: 0))
        expect(error).toNot(beNil())
        expect(String(describing: error!)).to(equal("Fleet error: Attempted to select cell action on table view without a data source"))
    }

    func test_selectCellAction_whenNoDelegateSet_returnsAnError() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        viewController.birdsTableView?.delegate = nil

        let error = viewController.birdsTableView?.selectCellAction(withTitle: "Two", at: IndexPath(row: 10, section: 0))
        expect(error).toNot(beNil())
        expect(String(describing: error!)).to(equal("Fleet error: UITableViewDelegate required for cells to perform actions"))
    }

    func test_selectCellAction_whenDelegateDoesNotImplementEditActionsMethod_returnsAnError() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view


        class MinimalDelegate: NSObject, UITableViewDelegate {}

        let minimalDelegate = MinimalDelegate()
        viewController.birdsTableView?.delegate = minimalDelegate

        let error = viewController.birdsTableView?.selectCellAction(withTitle: "Two", at: IndexPath(row: 10, section: 0))
        expect(error).toNot(beNil())
        expect(String(describing: error!)).to(equal("Fleet error: Delegate must implement `UITableViewDelegate.editActionsForRowAt:` method to use cell actions"))
    }
}
