import XCTest
import Fleet
import Nimble

@testable import FleetTestApp

class UITableView_FleetSpec: XCTestCase {
    func test_selectRow_whenACellExistsAtThatIndexPath_selectsTheCell() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        let _ = viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))

        guard let selectedIndexPath = viewController.birdsTableView?.indexPathForSelectedRow else {
            fail("Failed to select row at index path (\(IndexPath(row: 1, section: 0)))")
            return
        }

        expect(selectedIndexPath).to(equal(IndexPath(row: 1, section: 0)))
    }

    func test_selectRow_whenACellWasPreviouslySelected_deselectsThePreviouslySelectedCell() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        let _ = viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))
        let _ = viewController.birdsTableView?.selectRow(at: IndexPath(row: 4, section: 0))

        guard let selectedIndexPaths = viewController.birdsTableView?.indexPathsForSelectedRows else {
            fail("Failed to select any rows")
            return
        }

        expect(selectedIndexPaths.count).to(equal(1))
        expect(selectedIndexPaths.first).to(equal(IndexPath(row: 4, section: 0)))
    }

    func test_selectRow_whenACellExistsAtThatIndexPath_firesWillSelectAndDidSelectDelegateMethods() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))

        expect(error).to(beNil())
        expect(viewController.willSelectRowCallCount).to(equal(1))
        expect(viewController.willSelectRowCallArgs[0]).to(equal(IndexPath(row: 1, section: 0)))
        expect(viewController.didSelectRowCallCount).to(equal(1))
        expect(viewController.didSelectRowCallArgs[0]).to(equal(IndexPath(row: 1, section: 0)))
    }

    func test_selectRow_whenACellExistsAtThatIndexPath_firesWillDeselectAndDidDeselectDelegateMethods() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        let _ = viewController.birdsTableView?.selectRow(at: IndexPath(row: 10, section: 0))
        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))

        expect(error).to(beNil())
        expect(viewController.willDeselectRowCallCount).to(equal(1))
        expect(viewController.willDeselectRowCallArgs[0]).to(equal(IndexPath(row: 10, section: 0)))
        expect(viewController.didDeselectRowCallCount).to(equal(1))
        expect(viewController.didDeselectRowCallArgs[0]).to(equal(IndexPath(row: 10, section: 0)))
    }

    func test_selectRow_whenTheDelegateDoesNotAllowSelectionOfThatIndexPath_callsWillSelectAndNotDidSelectOnDelegate() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        // The controller does not allow the first row to be selected.
        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 0, section: 0))

        expect(error).to(beNil())
        expect(viewController.willSelectRowCallCount).to(equal(1))
        expect(viewController.didSelectRowCallCount).to(equal(0))
    }

    func test_selectRow_whenTheDelegateDoesNotAllowDeselectionOfThatIndexPath_callsWillDeselectAndNotDidDeselectOnDelegate() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        // The controller does not allow the fifth row to be deselected.
        let _ = viewController.birdsTableView?.selectRow(at: IndexPath(row: 4, section: 0))
        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 8, section: 0))

        expect(error).to(beNil())
        expect(viewController.willDeselectRowCallCount).to(equal(1))
        expect(viewController.didDeselectRowCallCount).to(equal(0))
    }

    func test_selectRow_whenTheDelegateChangesSelectionToAnotherIndexPath_callsDidSelectMethodWithOtherIndexPath() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        // The controller reroutes selection of the third row to the second row.
        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 2, section: 0))

        expect(error).to(beNil())
        expect(viewController.willSelectRowCallCount).to(equal(1))
        expect(viewController.willSelectRowCallArgs[0]).to(equal(IndexPath(row: 2, section: 0)))
        expect(viewController.didSelectRowCallCount).to(equal(1))
        expect(viewController.didSelectRowCallArgs[0]).to(equal(IndexPath(row: 1, section: 0)))
    }

    func test_selectRow_whenTheDelegateChangesDeselectionToAnotherIndexPath_callsDidDeselectMethodWithOtherIndexPath() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        // The controller reroutes selection of the seventh row to the sixth row.
        let _ = viewController.birdsTableView?.selectRow(at: IndexPath(row: 6, section: 0))
        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 10, section: 0))

        expect(error).to(beNil())
        expect(viewController.willDeselectRowCallCount).to(equal(1))
        expect(viewController.willDeselectRowCallArgs[0]).to(equal(IndexPath(row: 6, section: 0)))
        expect(viewController.didDeselectRowCallCount).to(equal(1))
        expect(viewController.didDeselectRowCallArgs[0]).to(equal(IndexPath(row: 5, section: 0)))
    }

    func test_selectRow_whenNoCellExistsAtThatIndexPath_whenInvalidSectionInIndexPath_returnsAnError() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 1))

        expect(error).toNot(beNil())
        expect(String(describing: error!)).to(equal("Fleet error: Invalid index path: Table view has no section 1 (section count in table view == 1)"))
    }

    func test_selectRow_whenNoCellExistsAtThatIndexPath_whenInvalidRowInIndexPath_returnsAnError() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 100, section: 0))

        expect(error).toNot(beNil())
        expect(String(describing: error!)).to(equal("Fleet error: Invalid index path: Section 0 does not have row 100 (row count in section 0 == 21)"))
    }

    func test_selectRow_whenSelectionIsValid_postsUITableViewSelectionDidChangeNotification() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        class Listener: NSObject {
            fileprivate var callCount = 0
            func listen() {
                callCount += 1
            }
        }

        let listener = Listener()

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(listener,
                                       selector: #selector(Listener.listen),
                                       name: NSNotification.Name.UITableViewSelectionDidChange,
                                       object: nil
        )

        let _ = viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))

        expect(listener.callCount).to(equal(1))
    }

    func test_selectRow_whenTableViewDoesNotAllowSelection_returnsAnError() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        viewController.birdsTableView?.allowsSelection = false

        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 0, section: 0))
        expect(error).toNot(beNil())
        expect(String(describing: error!)).to(equal("Fleet error: Attempted to select row on table view with 'allowsSelection' == false"))
    }

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
}
