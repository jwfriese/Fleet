import XCTest
import Fleet
import Nimble

#if os(iOS)
    @testable import FleetTestApp
#elseif os(tvOS)
    @testable import FleetTestApp_tvOS
#endif

@MainActor
class UITableView_SelectRowSpec: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
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

    func test_selectRow_whenSectionInIndexPathIsNegative_raisesException() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        expect { viewController.birdsTableView?.selectRow(at: IndexPath(row: 0, section: -1)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no section -1.", userInfo: nil, closure: nil)
        )
        expect(viewController.willSelectRowCallCount).to(equal(0))
        expect(viewController.birdsTableView?.indexPathForSelectedRow).to(beNil())
    }

    func test_selectRow_whenRowInIndexPathIsNegative_raisesException() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        expect { viewController.birdsTableView?.selectRow(at: IndexPath(row: -1, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no row -1 in section 0.", userInfo: nil, closure: nil)
        )
        expect(viewController.willSelectRowCallCount).to(equal(0))
        expect(viewController.birdsTableView?.indexPathForSelectedRow).to(beNil())
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

    func test_selectRow_whenSelectingAnotherRow_firesCallbacksInUIKitOrder() {
        let viewController = makeBirdsViewController()
        let table = viewController.birdsTableView!
        let recorder = RecordingDelegate()
        recorder.dataSource = table.dataSource
        table.delegate = recorder
        table.selectRow(at: IndexPath(row: 1, section: 0))
        recorder.events = []

        table.selectRow(at: IndexPath(row: 4, section: 0))

        expect(recorder.events).to(equal([
            "willSelect 4", "willDeselect 1", "didDeselect 1", "didSelect 4"
        ]))
    }

    func test_selectRow_whenDelegateVetoesSelection_doesNotDeselectPreviousRow() {
        let viewController = makeBirdsViewController()
        let table = viewController.birdsTableView!
        table.selectRow(at: IndexPath(row: 1, section: 0))

        // The controller does not allow the first row to be selected.
        table.selectRow(at: IndexPath(row: 0, section: 0))

        expect(table.indexPathsForSelectedRows).to(equal([IndexPath(row: 1, section: 0)]))
        expect(viewController.willDeselectRowCallCount).to(equal(0))
    }

    func test_selectRow_whenDelegateRedirectsToANonexistentRow_raisesAndChangesNothing() {
        let viewController = makeBirdsViewController()
        let table = viewController.birdsTableView!
        table.selectRow(at: IndexPath(row: 1, section: 0))
        let recorder = RecordingDelegate()
        recorder.dataSource = table.dataSource
        recorder.redirect = IndexPath(row: 500, section: 0)
        table.delegate = recorder

        expect { table.selectRow(at: IndexPath(row: 2, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no row 500 in section 0.", userInfo: nil, closure: nil)
        )
        expect(table.indexPathsForSelectedRows).to(equal([IndexPath(row: 1, section: 0)]))
        expect(recorder.events).to(equal(["willSelect 2"]))
    }

    func test_selectRow_whenDelegateRedirectsDeselectionToANonexistentRow_raisesAndChangesNothing() {
        let viewController = makeBirdsViewController()
        let table = viewController.birdsTableView!
        let recorder = RecordingDelegate()
        recorder.dataSource = table.dataSource
        table.delegate = recorder
        table.selectRow(at: IndexPath(row: 1, section: 0))
        recorder.events = []
        recorder.deselectRedirect = IndexPath(row: 500, section: 0)

        expect { table.selectRow(at: IndexPath(row: 3, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Table view has no row 500 in section 0.", userInfo: nil, closure: nil)
        )
        expect(table.indexPathsForSelectedRows).to(equal([IndexPath(row: 1, section: 0)]))
        expect(recorder.events).to(equal(["willSelect 3", "willDeselect 1"]))
    }

    func test_selectRow_withMultipleSelection_whenDeselectionRedirectIsNonexistent_raisesAndChangesNothing() {
        let viewController = makeBirdsViewController()
        let table = viewController.birdsTableView!
        table.allowsMultipleSelection = true
        table.selectRow(at: IndexPath(row: 1, section: 0))
        let recorder = RecordingDelegate()
        recorder.dataSource = table.dataSource
        recorder.deselectRedirect = IndexPath(row: 500, section: 0)
        table.delegate = recorder

        expect { table.selectRow(at: IndexPath(row: 1, section: 0)) }.to(raiseException())
        expect(table.indexPathsForSelectedRows).to(equal([IndexPath(row: 1, section: 0)]))
        expect(recorder.events).to(equal(["willSelect 1", "willDeselect 1"]))
    }

    func test_selectRowOrThrow_reportsFailuresAsSwiftErrors() {
        let viewController = makeBirdsViewController()
        let table = viewController.birdsTableView!

        XCTAssertThrowsError(try table.selectRowOrThrow(at: IndexPath(row: 500, section: 0))) { error in
            let failure = error as? FleetFailure
            XCTAssertEqual(failure?.kind, .invalidInput)
            XCTAssertEqual(failure?.action, "select row")
            XCTAssertEqual(failure?.target, "UITableView row 500 in section 0")
        }
        XCTAssertThrowsError(try table.selectRowOrThrow(at: IndexPath(index: 0))) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidInput)
        }
        table.allowsSelection = false
        XCTAssertThrowsError(try table.selectRowOrThrow(at: IndexPath(row: 1, section: 0))) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .unavailableInteraction)
        }
        table.dataSource = nil
        XCTAssertThrowsError(try table.selectRowOrThrow(at: IndexPath(row: 1, section: 0))) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidSetup)
        }
    }

    func test_selectRowOrThrow_reportsDelegateRefusalAsAnOutcome() throws {
        let viewController = makeBirdsViewController()
        let table = viewController.birdsTableView!

        // The controller does not allow the first row to be selected.
        let outcome = try table.selectRowOrThrow(at: IndexPath(row: 0, section: 0))

        XCTAssertEqual(outcome, .refusedByDelegate(method: "tableView(_:willSelectRowAt:)"))
        XCTAssertNil(table.indexPathsForSelectedRows)
        XCTAssertEqual(try table.selectRowOrThrow(at: IndexPath(row: 1, section: 0)), .performed)
    }

    func test_selectRowOrThrow_withMultipleSelection_whenDelegateVetoesDeselection_reportsRefusal() throws {
        let viewController = makeBirdsViewController()
        let table = viewController.birdsTableView!
        table.allowsMultipleSelection = true
        try table.selectRowOrThrow(at: IndexPath(row: 1, section: 0))
        let recorder = RecordingDelegate()
        recorder.dataSource = table.dataSource
        recorder.vetoDeselect = true
        table.delegate = recorder

        let outcome = try table.selectRowOrThrow(at: IndexPath(row: 1, section: 0))

        XCTAssertEqual(outcome, .refusedByDelegate(method: "tableView(_:willDeselectRowAt:)"))
        XCTAssertEqual(table.indexPathsForSelectedRows, [IndexPath(row: 1, section: 0)])
        XCTAssertEqual(recorder.events, ["willSelect 1", "willDeselect 1"])
    }

    func test_selectRow_whenRowIsAlreadySelected_reportsSelectionAgainWithoutDeselecting() {
        let viewController = makeBirdsViewController()
        let table = viewController.birdsTableView!
        table.selectRow(at: IndexPath(row: 1, section: 0))
        table.selectRow(at: IndexPath(row: 1, section: 0))

        expect(table.indexPathsForSelectedRows).to(equal([IndexPath(row: 1, section: 0)]))
        expect(viewController.didSelectRowCallCount).to(equal(2))
        expect(viewController.willDeselectRowCallCount).to(equal(0))
    }

    func test_selectRow_withMultipleSelection_keepsOtherRowsAndDeselectsATappedSelectedRow() {
        let viewController = makeBirdsViewController()
        let table = viewController.birdsTableView!
        table.allowsMultipleSelection = true

        table.selectRow(at: IndexPath(row: 1, section: 0))
        table.selectRow(at: IndexPath(row: 3, section: 0))
        expect(Set(table.indexPathsForSelectedRows ?? [])).to(equal([IndexPath(row: 1, section: 0), IndexPath(row: 3, section: 0)]))
        expect(viewController.willDeselectRowCallCount).to(equal(0))

        table.selectRow(at: IndexPath(row: 1, section: 0))
        expect(table.indexPathsForSelectedRows).to(equal([IndexPath(row: 3, section: 0)]))
        expect(viewController.didDeselectRowCallArgs).to(equal([IndexPath(row: 1, section: 0)]))
    }

    func test_selectRow_whenEditing_requiresAllowsSelectionDuringEditing() {
        let viewController = makeBirdsViewController()
        let table = viewController.birdsTableView!
        table.allowsSelectionDuringEditing = false
        table.isEditing = true

        expect { table.selectRow(at: IndexPath(row: 1, section: 0)) }.to(
            raiseException(named: "Fleet.TableViewError", reason: "Interaction with row 1 in section 0 rejected: Table view does not allow selection during editing.", userInfo: nil, closure: nil)
        )

        table.allowsSelectionDuringEditing = true
        table.selectRow(at: IndexPath(row: 1, section: 0))
        expect(table.indexPathForSelectedRow).to(equal(IndexPath(row: 1, section: 0)))
    }

    func test_selectRow_postsNotificationWithTheTableViewAsObject() {
        let viewController = makeBirdsViewController()
        let table = viewController.birdsTableView!
        let observer = ObjectRecordingObserver()
        NotificationCenter.default.addObserver(observer, selector: #selector(ObjectRecordingObserver.observe(_:)), name: UITableView.selectionDidChangeNotification, object: nil)
        defer { NotificationCenter.default.removeObserver(observer) }

        table.selectRow(at: IndexPath(row: 1, section: 0))

        expect(observer.objects.count).to(equal(1))
        expect(observer.objects.first!).to(beIdenticalTo(table))
    }

    private func makeBirdsViewController() -> BirdsViewController {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view
        return viewController
    }
}

@MainActor
fileprivate class RecordingDelegate: NSObject, UITableViewDelegate {
    var events: [String] = []
    var redirect: IndexPath?
    var deselectRedirect: IndexPath?
    var vetoDeselect = false
    weak var dataSource: UITableViewDataSource?

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        events.append("willSelect \(indexPath.row)")
        return redirect ?? indexPath
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { events.append("didSelect \(indexPath.row)") }
    func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
        events.append("willDeselect \(indexPath.row)")
        if vetoDeselect { return nil }
        return deselectRedirect ?? indexPath
    }
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) { events.append("didDeselect \(indexPath.row)") }
}

@MainActor
fileprivate class ObjectRecordingObserver: NSObject {
    var objects: [AnyObject] = []
    @objc func observe(_ notification: Notification) {
        if let object = notification.object as AnyObject? { objects.append(object) }
    }
}
