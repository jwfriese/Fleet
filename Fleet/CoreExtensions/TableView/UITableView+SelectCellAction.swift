import UIKit

public extension UITableView {
    /**
    Mimic a user taking an edit action on the cell at the given index path in
    the table view.

    - parameters:
        - title: The title of the edit action to take
        - at: The index path at which to attempt to take this action

    - returns:
    Nil if edit action was taken successfully, otherwise a FleetError is there is no cell at
    the given index path, if the data source does not allow editing of the given index path,
    or if there is no edit action with the given title on the cell.
    */
    func selectCellAction(withTitle title: String, at indexPath: IndexPath) -> FleetError? {
        guard let dataSource = dataSource else {
            return FleetError(message: "Attempted to select cell action on table view without a data source")
        }

        guard let delegate = delegate else {
            return FleetError(message: "UITableViewDelegate required for cells to perform actions")
        }

        if !delegate.responds(to: #selector(UITableViewDelegate.tableView(_:editActionsForRowAt:))) {
            return FleetError(message: "Delegate must implement `UITableViewDelegate.editActionsForRowAt:` method to use cell actions")
        }

        let sectionCount = numberOfSections
        if indexPath.section >= sectionCount {
            return FleetError(message: "Invalid index path: Table view has no section \(indexPath.section) (section count in table view == \(sectionCount))")
        }

        let rowCount = numberOfRows(inSection: indexPath.section)
        if indexPath.row >= rowCount {
            return FleetError(message: "Invalid index path: Section \(indexPath.section) does not have row \(indexPath.row) (row count in section \(indexPath.section) == \(rowCount))")
        }

        let doesDataSourceImplementCanEditRow = dataSource.responds(to: #selector(UITableViewDataSource.tableView(_:canEditRowAt:)))
        let canEditCell = doesDataSourceImplementCanEditRow && dataSource.tableView!(self, canEditRowAt: indexPath)
        if !canEditCell {
            return FleetError(message: "Editing of row \(indexPath.row) in section \(indexPath.section) is not allowed by the table view's data source")
        }

        let editActions = delegate.tableView!(self, editActionsForRowAt: indexPath)
        let actionOpt = editActions?.first() { element in
            return element.title == title
        }

        guard let action = actionOpt else {
            return FleetError(message: "Could not find edit action with title '\(title)' at row \(indexPath.row) in section \(indexPath.section)")
        }

        delegate.tableView?(self, willBeginEditingRowAt: indexPath)
        action.handler!(action, indexPath)
        delegate.tableView?(self, didEndEditingRowAt: indexPath)
        return nil
    }
}
