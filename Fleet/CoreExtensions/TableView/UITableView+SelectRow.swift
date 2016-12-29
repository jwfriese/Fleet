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
        guard let _ = self.dataSource else {
            return FleetError(message: "Attempted to select row on table view without a data source")
        }

        guard allowsSelection else {
            return FleetError(message: "Attempted to select row on table view with 'allowsSelection' == false")
        }

        let sectionCount = numberOfSections
        if indexPath.section >= sectionCount {
            return FleetError(message: "Invalid index path: Table view has no section \(indexPath.section) (section count in table view == \(sectionCount))")
        }

        let rowCount = numberOfRows(inSection: indexPath.section)
        if indexPath.row >= rowCount {
            return FleetError(message: "Invalid index path: Section \(indexPath.section) does not have row \(indexPath.row) (row count in section \(indexPath.section) == \(rowCount))")
        }

        let hasDelegate = delegate != nil
        let doesDelegateImplementWillDeselect = hasDelegate && delegate!.responds(to: #selector(UITableViewDelegate.tableView(_:willDeselectRowAt:)))
        if doesDelegateImplementWillDeselect {
            deselectPreviouslySelectedRow()
        }

        var indexPathToSelect = indexPath
        let doesDelegateImplementWillSelect = hasDelegate && delegate!.responds(to: #selector(UITableViewDelegate.tableView(_:willSelectRowAt:)))
        if doesDelegateImplementWillSelect {
            let indexPathToSelectOptional = delegate!.tableView!(self, willSelectRowAt: indexPath)
            guard let unwrappedIndexPathToSelect = indexPathToSelectOptional else {
                return nil
            }

            indexPathToSelect = unwrappedIndexPathToSelect
        }

        selectRow(at: indexPath, animated: false, scrollPosition: .none)
        NotificationCenter.default.post(name: NSNotification.Name.UITableViewSelectionDidChange, object: nil)

        delegate?.tableView?(self, didSelectRowAt: indexPathToSelect)
        return nil
    }

    private func deselectPreviouslySelectedRow() {
        if let selectedRowIndexPath = indexPathForSelectedRow {
            let indexPathToDeselectOptional = delegate!.tableView!(self, willDeselectRowAt: selectedRowIndexPath)
            if let indexPathToDeselect = indexPathToDeselectOptional {
                deselectRow(at: indexPathToDeselect, animated: false)
                NotificationCenter.default.post(name: NSNotification.Name.UITableViewSelectionDidChange, object: nil)
                delegate?.tableView?(self, didDeselectRowAt: indexPathToDeselect)
            }
        }
    }
}
