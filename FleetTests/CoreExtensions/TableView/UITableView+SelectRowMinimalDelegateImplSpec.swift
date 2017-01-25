import XCTest
import Fleet
import Nimble

@testable import FleetTestApp
import UIKit

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

class UITableView_SelectRowMinimalDelegateImplSpec: XCTestCase {
    func test_selectRow_whenTheDelegateDoesNotImplementWillSelect_stillSelectsRow() {
        let storyboard = UIStoryboard(name: "Birds", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "BirdsViewController") as! BirdsViewController
        let _ = viewController.view

        let delegate = MinimallyImplementedDelegate()
        viewController.birdsTableView?.delegate = delegate
        viewController.birdsTableView?.dataSource = delegate

        try! viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))

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

        try! viewController.birdsTableView?.selectRow(at: IndexPath(row: 1, section: 0))
        try! viewController.birdsTableView?.selectRow(at: IndexPath(row: 4, section: 0))

        guard let selectedIndexPaths = viewController.birdsTableView?.indexPathsForSelectedRows else {
            fail("Failed to select any rows")
            return
        }

        expect(selectedIndexPaths.count).to(equal(1))
        expect(selectedIndexPaths.first).to(equal(IndexPath(row: 4, section: 0)))
    }
}
