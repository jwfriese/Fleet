import XCTest
import Fleet
import Nimble

@testable import FleetTestApp

@MainActor
class UITableView_ContextualActionsSpec: XCTestCase {
    private var viewController: BirdsViewController!
    private var tableView: UITableView!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as? BirdsViewController
        _ = viewController.view
        tableView = viewController.birdsTableView
    }

    override func tearDown() async throws {
        viewController = nil
        tableView = nil
        try await super.tearDown()
    }

    private func expectFailure(_ reason: String, _ action: @escaping () -> Void, file: FileString = #filePath, line: UInt = #line) {
        expect(file: file, line: line, action()).to(
            raiseException(named: "Fleet.TableViewError", reason: reason, userInfo: nil, closure: nil)
        )
    }

    // MARK: Invocation

    func test_performContextualAction_trailingByTitle_invokesTheHandlerOnce() {
        let result = tableView.performContextualAction(withTitle: "Two", edge: .trailing, at: IndexPath(row: 10, section: 0))

        expect(result).to(beTrue())
        expect(self.viewController.contextualActionCalls.map { $0.title }).to(equal(["Two"]))
        expect(self.viewController.contextualActionCalls.first?.indexPath).to(equal(IndexPath(row: 10, section: 0)))
    }

    func test_performContextualAction_trailingByTitle_presentsAlertFromHandler() {
        Fleet.setAsAppWindowRoot(viewController)

        tableView.performContextualAction(withTitle: "Two", edge: .trailing, at: IndexPath(row: 10, section: 0))

        let alertMessage: () -> String? = {
            (Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController)?.message
        }
        expect(alertMessage()).toEventually(equal("Two tapped at row 10"))
    }

    func test_performContextualAction_leadingByTitle_invokesTheLeadingHandler() {
        let result = tableView.performContextualAction(withTitle: "Pin", edge: .leading, at: IndexPath(row: 2, section: 0))

        expect(result).to(beTrue())
        expect(self.viewController.contextualActionCalls.map { $0.title }).to(equal(["Pin"]))
    }

    func test_performContextualAction_byIndex_invokesThatAction() {
        tableView.performContextualAction(atIndex: 2, edge: .trailing, at: IndexPath(row: 1, section: 0))

        expect(self.viewController.contextualActionCalls.map { $0.title }).to(equal(["Three"]))
    }

    func test_performContextualAction_byIndex_canSelectBetweenDuplicateTitles() {
        tableView.performContextualAction(atIndex: 3, edge: .trailing, at: IndexPath(row: 5, section: 0))

        expect(self.viewController.contextualActionCalls.map { $0.title }).to(equal(["Twice (second)"]))
    }

    func test_performContextualAction_passesTheRowsCellAsTheSourceView() {
        let indexPath = IndexPath(row: 1, section: 0)
        Fleet.setAsAppWindowRoot(viewController)
        let visibleCell = tableView.cellForRow(at: indexPath)
        expect(visibleCell).toNot(beNil())

        tableView.performContextualAction(withTitle: "One", edge: .trailing, at: indexPath)

        expect(self.viewController.contextualActionCalls.first?.sourceView).to(beIdenticalTo(visibleCell))
    }

    func test_performContextualAction_callsEditingDelegateMethodsAroundTheHandler() {
        let indexPath = IndexPath(row: 10, section: 0)

        tableView.performContextualAction(withTitle: "Two", edge: .trailing, at: indexPath)

        expect(self.viewController.willBeginEditingRowCallArgs).to(equal([indexPath]))
        expect(self.viewController.didEndEditingRowCallArgs).to(equal([indexPath]))
    }

    // MARK: Completion

    func test_performContextualAction_whenHandlerReportsRefusal_returnsFalse() {
        let result = tableView.performContextualAction(withTitle: "Refuse", edge: .leading, at: IndexPath(row: 2, section: 0))

        expect(result).to(beFalse())
        expect(self.viewController.contextualActionCalls.map { $0.title }).to(equal(["Refuse"]))
        expect(self.viewController.didEndEditingRowCallArgs.count).to(equal(1))
    }

    func test_performContextualAction_whenHandlerCompletesAsynchronously_waitsForCompletion() {
        let result = tableView.performContextualAction(withTitle: "Later", edge: .trailing, at: IndexPath(row: 5, section: 0))

        expect(result).to(beTrue())
        expect(self.viewController.didEndEditingRowCallArgs.count).to(equal(1))
    }

    func test_performContextualAction_whenHandlerNeverCompletes_failsWithinTheTimeout() {
        let start = Date()

        expectFailure("The trailing contextual action 'Never' at row 5 in section 0 did not call its completion handler within 0.3 seconds.") {
            self.tableView.performContextualAction(withTitle: "Never", edge: .trailing, at: IndexPath(row: 5, section: 0), completionTimeout: 0.3)
        }

        expect(Date().timeIntervalSince(start)).to(beLessThan(5))
        expect(self.viewController.contextualActionCalls.map { $0.title }).to(equal(["Never"]))
        expect(self.viewController.didEndEditingRowCallArgs).to(beEmpty())
    }

    // MARK: Invalid requests

    func test_performContextualAction_whenTitleDoesNotExist_raisesException() {
        expectFailure("Could not find trailing contextual action with title 'Four' at row 10 in section 0.") {
            self.tableView.performContextualAction(withTitle: "Four", edge: .trailing, at: IndexPath(row: 10, section: 0))
        }
        expect(self.viewController.contextualActionCalls).to(beEmpty())
    }

    func test_performContextualAction_whenTitleExistsOnlyOnTheOtherEdge_raisesException() {
        expectFailure("Could not find leading contextual action with title 'One' at row 10 in section 0.") {
            self.tableView.performContextualAction(withTitle: "One", edge: .leading, at: IndexPath(row: 10, section: 0))
        }
    }

    func test_performContextualAction_whenTitleIsAmbiguous_raisesExceptionWithoutInvokingAnything() {
        expectFailure("Found 2 trailing contextual actions with title 'Twice' at row 5 in section 0; select one by index instead.") {
            self.tableView.performContextualAction(withTitle: "Twice", edge: .trailing, at: IndexPath(row: 5, section: 0))
        }
        expect(self.viewController.contextualActionCalls).to(beEmpty())
    }

    func test_performContextualAction_whenIndexIsOutOfRange_raisesException() {
        expectFailure("Row 1 in section 0 has 3 trailing contextual actions; no action at index 3.") {
            self.tableView.performContextualAction(atIndex: 3, edge: .trailing, at: IndexPath(row: 1, section: 0))
        }
        expectFailure("Row 1 in section 0 has 3 trailing contextual actions; no action at index -1.") {
            self.tableView.performContextualAction(atIndex: -1, edge: .trailing, at: IndexPath(row: 1, section: 0))
        }
    }

    func test_performContextualAction_whenDelegateReturnsNoConfiguration_raisesException() {
        expectFailure("Row 4 in section 0 has no trailing contextual actions.") {
            self.tableView.performContextualAction(withTitle: "One", edge: .trailing, at: IndexPath(row: 4, section: 0))
        }
    }

    func test_performContextualAction_whenInvalidSection_raisesException() {
        expectFailure("Table view has no section 1.") {
            self.tableView.performContextualAction(withTitle: "One", edge: .trailing, at: IndexPath(row: 1, section: 1))
        }
    }

    func test_performContextualAction_whenInvalidRow_raisesException() {
        expectFailure("Table view has no row 100 in section 0.") {
            self.tableView.performContextualAction(withTitle: "One", edge: .trailing, at: IndexPath(row: 100, section: 0))
        }
        expectFailure("Table view has no row -1 in section 0.") {
            self.tableView.performContextualAction(withTitle: "One", edge: .trailing, at: IndexPath(row: -1, section: 0))
        }
    }

    func test_performContextualAction_whenDataSourceDisallowsEditing_raisesException() {
        // The fourth row in the table view is not editable
        expectFailure("Interaction with row 3 in section 0 rejected: Table view data source does not allow editing of that row.") {
            self.tableView.performContextualAction(withTitle: "One", edge: .trailing, at: IndexPath(row: 3, section: 0))
        }
    }

    func test_performContextualAction_whenNoDataSource_raisesException() {
        tableView.dataSource = nil

        expectFailure("Data source required to perform contextual action.") {
            self.tableView.performContextualAction(withTitle: "Two", edge: .trailing, at: IndexPath(row: 10, section: 0))
        }
    }

    func test_performContextualAction_whenNoDelegate_raisesException() {
        tableView.delegate = nil

        expectFailure("Delegate required to perform contextual action.") {
            self.tableView.performContextualAction(withTitle: "Two", edge: .trailing, at: IndexPath(row: 10, section: 0))
        }
    }

    func test_performContextualAction_whenDelegateDoesNotImplementTheEdgesMethod_raisesException() {
        class MinimalDelegate: NSObject, UITableViewDelegate {}
        let minimalDelegate = MinimalDelegate()
        tableView.delegate = minimalDelegate

        expectFailure("Delegate must implement UITableViewDelegate.tableView(_:leadingSwipeActionsConfigurationForRowAt:) to perform contextual action.") {
            self.tableView.performContextualAction(withTitle: "Pin", edge: .leading, at: IndexPath(row: 2, section: 0))
        }
        expectFailure("Delegate must implement UITableViewDelegate.tableView(_:trailingSwipeActionsConfigurationForRowAt:) to perform contextual action.") {
            self.tableView.performContextualAction(atIndex: 0, edge: .trailing, at: IndexPath(row: 2, section: 0))
        }
    }

    // MARK: Swift concurrency

    func test_performContextualAction_async_completesFromMainActorTask() async {
        let delegate = TaskCompletingDelegate()
        tableView.delegate = delegate

        let result = await tableView.performContextualAction(withTitle: "Task", edge: .trailing, at: IndexPath(row: 0, section: 0), completionTimeout: 2)

        expect(result).to(beTrue())
        expect(delegate.invocationCount).to(equal(1))
    }
}

@MainActor
private final class TaskCompletingDelegate: NSObject, UITableViewDelegate {
    let completes: Bool
    private(set) var invocationCount = 0

    init(completes: Bool = true) {
        self.completes = completes
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .normal, title: "Task") { [weak self] _, _, completion in
            self?.invocationCount += 1
            guard self?.completes == true else { return }
            Task { @MainActor in completion(true) }
        }
        return UISwipeActionsConfiguration(actions: [action])
    }
}
