import UIKit

public extension UITableView {
    /**
    Mimic a user tap on the cell at the given index path in the table view.
    Unlike UITableView's selectRow(at:animated:scrollPosition:) method, this
    method fires the table view's hooked-in delegate call backs and sends a
    notification.

    - parameters:
        - at: The index path to attempt to tap

    - returns:
    A FleetError if the there is no cell at the given index path, otherwise nil.
    */
    public func selectRow(at indexPath: IndexPath) -> FleetError? {
        let sectionCount = self.numberOfSections
        if indexPath.section >= sectionCount {
            return FleetError(message: "Invalid index path: Table view has no section \(indexPath.section) (section count in table view == \(sectionCount))")
        }

        let rowCount = self.numberOfRows(inSection: indexPath.section)
        if indexPath.row >= rowCount {
            return FleetError(message: "Invalid index path: Section \(indexPath.section) does not have row \(indexPath.row) (row count in section \(indexPath.section) == \(rowCount))")
        }

        let indexPathToSelectOptional = self.delegate!.tableView!(self, willSelectRowAt: indexPath)
        guard let indexPathToSelect = indexPathToSelectOptional else {
            return nil
        }

        self.delegate!.tableView!(self, didSelectRowAt: indexPathToSelect)
        return nil
    }
}
