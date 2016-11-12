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
    Nil if selection is successful, otherwise a FleetError if there is no cell at the given index path
    or if the table view does not allow selection ('allowsSelection' == false)
    */
    public func selectRow(at indexPath: IndexPath) -> FleetError? {
        guard allowsSelection else {
            return FleetError(message: "Attempted to select row on table view with 'allowsSelection' == false")
        }

        let sectionCount = self.numberOfSections
        if indexPath.section >= sectionCount {
            return FleetError(message: "Invalid index path: Table view has no section \(indexPath.section) (section count in table view == \(sectionCount))")
        }

        let rowCount = self.numberOfRows(inSection: indexPath.section)
        if indexPath.row >= rowCount {
            return FleetError(message: "Invalid index path: Section \(indexPath.section) does not have row \(indexPath.row) (row count in section \(indexPath.section) == \(rowCount))")
        }

        self.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        NotificationCenter.default.post(name: NSNotification.Name.UITableViewSelectionDidChange, object: nil)

        let indexPathToSelectOptional = self.delegate!.tableView!(self, willSelectRowAt: indexPath)
        guard let indexPathToSelect = indexPathToSelectOptional else {
            return nil
        }

        self.delegate!.tableView!(self, didSelectRowAt: indexPathToSelect)
        return nil
    }
}
