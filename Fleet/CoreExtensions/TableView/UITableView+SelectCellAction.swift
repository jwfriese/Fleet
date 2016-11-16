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
        let sectionCount = self.numberOfSections
        if indexPath.section >= sectionCount {
            return FleetError(message: "Invalid index path: Table view has no section \(indexPath.section) (section count in table view == \(sectionCount))")
        }

        let rowCount = self.numberOfRows(inSection: indexPath.section)
        if indexPath.row >= rowCount {
            return FleetError(message: "Invalid index path: Section \(indexPath.section) does not have row \(indexPath.row) (row count in section \(indexPath.section) == \(rowCount))")
        }

        guard dataSource!.tableView!(self, canEditRowAt: indexPath) else {
            return FleetError(message: "Editing of row \(indexPath.row) in section \(indexPath.section) is not allowed by the table view's data source")
        }

        let editActions = delegate!.tableView!(self, editActionsForRowAt: indexPath)
        let actionOpt = editActions?.first() { element in
            return element.title == title
        }

        guard let action = actionOpt else {
            return FleetError(message: "Could not find edit action with title '\(title)' at row \(indexPath.row) in section \(indexPath.section)")
        }

        delegate!.tableView!(self, willBeginEditingRowAt: indexPath)
        action.handler!(action, indexPath)
        delegate!.tableView!(self, didEndEditingRowAt: indexPath)
        return nil
    }
}
