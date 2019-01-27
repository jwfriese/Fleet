import XCTest
import Fleet
import Nimble

#if os(iOS)
    @testable import FleetTestApp
#elseif os(tvOS)
    @testable import FleetTestApp_tvOS
#endif

class UITableView_SelectRowSpec: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_selectRow_whenACellExistsAtThatIndexPath_selectsTheCell() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))

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
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 4, section: 0))

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
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))

        expect(viewController.willSelectRowCallCount).to(equal(1))
        expect(viewController.willSelectRowCallArgs[0]).to(equal(IndexPath(row: 1, section: 0)))
        expect(viewController.didSelectRowCallCount).to(equal(1))
        expect(viewController.didSelectRowCallArgs[0]).to(equal(IndexPath(row: 1, section: 0)))
    }

    func test_selectRow_whenACellExistsAtThatIndexPath_firesWillDeselectAndDidDeselectDelegateMethods() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 10, section: 0))
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))

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
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 0, section: 0))

        expect(viewController.willSelectRowCallCount).to(equal(1))
        expect(viewController.didSelectRowCallCount).to(equal(0))
    }

    func test_selectRow_whenTheDelegateDoesNotAllowDeselectionOfThatIndexPath_callsWillDeselectAndNotDidDeselectOnDelegate() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        // The controller does not allow the fifth row to be deselected.
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 4, section: 0))
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 8, section: 0))

        expect(viewController.willDeselectRowCallCount).to(equal(1))
        expect(viewController.didDeselectRowCallCount).to(equal(0))
    }

    func test_selectRow_whenTheDelegateChangesSelectionToAnotherIndexPath_selectsTheCellWithOtherIndexPath() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        // The controller reroutes selection of the third row to the second row.
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 2, section: 0))

        guard let selectedIndexPath = viewController.birdsTableView?.indexPathForSelectedRow else {
            fail("Failed to select row at index path (\(IndexPath(row: 2, section: 0))), which should have been rerouted")
            return
        }

        expect(selectedIndexPath).to(equal(IndexPath(row: 1, section: 0)))
    }

    func test_selectRow_whenTheDelegateChangesSelectionToAnotherIndexPath_callsDidSelectMethodWithOtherIndexPath() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        // The controller reroutes selection of the third row to the second row.
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 2, section: 0))

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
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 6, section: 0))
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 10, section: 0))

        expect(viewController.willDeselectRowCallCount).to(equal(1))
        expect(viewController.willDeselectRowCallArgs[0]).to(equal(IndexPath(row: 6, section: 0)))
        expect(viewController.didDeselectRowCallCount).to(equal(1))
        expect(viewController.didDeselectRowCallArgs[0]).to(equal(IndexPath(row: 5, section: 0)))
    }

    func test_selectRow_whenNoCellExistsAtThatIndexPath_whenInvalidSectionInIndexPath_raisesException() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        expect { viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 1)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no section 1.", userInfo: nil, closure: nil)
        )
    }

    func test_selectRow_whenNoCellExistsAtThatIndexPath_whenInvalidRowInIndexPath_raisesException() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        expect { viewController.birdsTableView?.selectRow(at: IndexPath(row: 100, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no row 100 in section 0.", userInfo: nil, closure: nil)
        )
    }

    func test_selectRow_whenSelectionIsValid_postsUITableViewSelectionDidChangeNotification() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        let listener = NotificationListener()

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(listener,
                                       selector: #selector(NotificationListener.listenTo(notification:)),
                                       name: UITableView.selectionDidChangeNotification,
                                       object: nil
        )

        viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))

        expect(listener.callCount(for: UITableView.selectionDidChangeNotification)).to(equal(1))
    }

    func test_selectRow_whenTableViewDoesNotHaveDataSource_raisesException() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        viewController.birdsTableView?.dataSource = nil

        expect { viewController.birdsTableView?.selectRow(at: IndexPath(row: 0, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Data source required to select cell row.", userInfo: nil, closure: nil)
        )
    }

    func test_selectRow_whenTableViewDoesNotAllowSelection_raisesException() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        viewController.birdsTableView?.allowsSelection = false

        expect { viewController.birdsTableView?.selectRow(at: IndexPath(row: 0, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Interaction with row 0 in section 0 rejected: Table view does not allow selection.", userInfo: nil, closure: nil)
        )
    }

    func test_selectRow_whenTableViewDoesNotHaveDelegate_stillSelectsTheRow() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        viewController.birdsTableView?.delegate = nil
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))

        guard let selectedIndexPath = viewController.birdsTableView?.indexPathForSelectedRow else {
            fail("Failed to select row at index path (\(IndexPath(row: 1, section: 0)))")
            return
        }

        expect(selectedIndexPath).to(equal(IndexPath(row: 1, section: 0)))
    }
}
