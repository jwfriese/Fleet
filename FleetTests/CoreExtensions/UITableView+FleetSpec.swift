import XCTest
import Fleet
import Nimble

@testable import FleetTestApp

class UITableView_FleetSpec: XCTestCase {
    func test_selectRow_whenACellExistsAtThatIndexPath_firesWillSelectAndDidSelectDelegateMethods() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateInitialViewController() as! BirdsViewController
        let _ = viewController.view
        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))

        expect(error).to(beNil())
        expect(viewController.willSelectRowCallCount).to(equal(1))
        expect(viewController.willSelectRowCallArgs[0]).to(equal(IndexPath(row: 1, section: 0)))
        expect(viewController.didSelectRowCallCount).to(equal(1))
        expect(viewController.didSelectRowCallArgs[0]).to(equal(IndexPath(row: 1, section: 0)))
    }

    func test_selectRow_whenTheDelegateDoesNotAllowSelectionOfThatIndexPath_callsWillSelectAndNotDidSelectOnDelegate() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateInitialViewController() as! BirdsViewController
        let _ = viewController.view

        // The controller does not allow the first row to be selected.
        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 0, section: 0))

        expect(error).to(beNil())
        expect(viewController.willSelectRowCallCount).to(equal(1))
        expect(viewController.didSelectRowCallCount).to(equal(0))
    }

    func test_selectRow_whenTheDelegateChangesSelectionToAnotherIndexPath_callsDidSelectMethodWithOtherIndexPath() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateInitialViewController() as! BirdsViewController
        let _ = viewController.view

        // The controller reroutes selection of the third row to the second row.
        let error = viewController.birdsTableView?.selectRow(at: IndexPath(row: 2, section: 0))

        expect(error).to(beNil())
        expect(viewController.willSelectRowCallCount).to(equal(1))
        expect(viewController.willSelectRowCallArgs[0]).to(equal(IndexPath(row: 2, section: 0)))
        expect(viewController.didSelectRowCallCount).to(equal(1))
        expect(viewController.didSelectRowCallArgs[0]).to(equal(IndexPath(row: 1, section: 0)))
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
