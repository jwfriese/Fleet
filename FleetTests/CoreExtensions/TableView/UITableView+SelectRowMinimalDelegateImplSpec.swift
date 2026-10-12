import XCTest
import Fleet
import Nimble

#if os(iOS)
    @testable import FleetTestApp
#elseif os(tvOS)
    @testable import FleetTestApp_tvOS
#endif

fileprivate class MinimallyImplementedDelegate: NSObject {}
extension MinimallyImplementedDelegate: UITableViewDelegate {}
extension MinimallyImplementedDelegate: UITableViewDataSource {
    fileprivate func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
    }

    fileprivate func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }
}

fileprivate class InvalidRedirectDelegate: MinimallyImplementedDelegate {
    var didDeselectCount = 0
    var didSelectCount = 0

    @objc func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
        return indexPath
    }

    @objc func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        return IndexPath(row: -1, section: 0)
    }

    @objc func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        didDeselectCount += 1
    }

    @objc func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectCount += 1
    }
}

@MainActor
class UITableView_SelectRowMinimalDelegateImplSpec: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
    }

    func test_selectRow_whenTheDelegateDoesNotImplementWillSelect_stillSelectsRow() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        let delegate = MinimallyImplementedDelegate()
        viewController.birdsTableView?.delegate = delegate
        viewController.birdsTableView?.dataSource = delegate

        viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))

        guard let selectedIndexPath = viewController.birdsTableView?.indexPathForSelectedRow else {
            fail("Failed to select row at index path (\(IndexPath(row: 1, section: 0)))")
            return
        }

        expect(selectedIndexPath).to(equal(IndexPath(row: 1, section: 0)))
    }

    func test_selectRow_whenACellWasPreviouslySelected_whenTheDelegateDoesNotImplementWillDeselect_stillDeselectsThePreviouslySelectedCell() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        let delegate = MinimallyImplementedDelegate()
        viewController.birdsTableView?.delegate = delegate
        viewController.birdsTableView?.dataSource = delegate

        viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))
        viewController.birdsTableView?.selectRow(at: IndexPath(row: 4, section: 0))

        guard let selectedIndexPaths = viewController.birdsTableView?.indexPathsForSelectedRows else {
            fail("Failed to select any rows")
            return
        }

        expect(selectedIndexPaths.count).to(equal(1))
        expect(selectedIndexPaths.first).to(equal(IndexPath(row: 4, section: 0)))
    }

    func test_selectRow_whenDelegateRedirectsToInvalidPath_raisesAndPreservesExistingSelectionWithoutCallbacks() {
        let table = UITableView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let delegate = InvalidRedirectDelegate()
        table.dataSource = delegate
        table.delegate = delegate
        table.layoutIfNeeded()

        let original = IndexPath(row: 0, section: 0)
        table.selectRow(at: original, animated: false, scrollPosition: .none)

        expect { table.selectRow(at: IndexPath(row: 1, section: 0)) }.to(raiseException())

        expect(table.indexPathForSelectedRow).to(equal(original))
        expect(delegate.didDeselectCount).to(equal(0))
        expect(delegate.didSelectCount).to(equal(0))
    }
}
