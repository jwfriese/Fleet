import UIKit

extension UITableView {
    /**
     Mimic a user taking an edit action on the cell at the given index path in
     the table view.

     - parameters:
        - title: The title of the edit action to take
        - at: The index path at which to attempt to take this action

     - throws:
     A `Fleet.TableViewError` is there is no cell at the given index path, if the data source
     does not allow editing of the given index path, or if there is no edit action with the
     given title on the cell.
     */
    public func selectCellAction(withTitle title: String, at indexPath: IndexPath) throws {
        guard let dataSource = dataSource else {
            throw Fleet.TableViewError.dataSourceRequired(userAction: "select cell action")
        }

        guard let delegate = delegate else {
            throw Fleet.TableViewError.delegateRequired(userAction: "select cell action")
        }

        if !delegate.responds(to: #selector(UITableViewDelegate.tableView(_:editActionsForRowAt:))) {
            throw Fleet.TableViewError.incompleteDelegate(required: "UITableViewDelegate.tableView(_:editActionsForRowAt:)", userAction: "select cell action")
        }

        let sectionCount = numberOfSections
        if indexPath.section >= sectionCount {
            throw Fleet.TableViewError.sectionDoesNotExist(sectionNumber: indexPath.section)
        }

        let rowCount = numberOfRows(inSection: indexPath.section)
        if indexPath.row >= rowCount {
            throw Fleet.TableViewError.rowDoesNotExist(at: indexPath)
        }

        let doesDataSourceImplementCanEditRow = dataSource.responds(to: #selector(UITableViewDataSource.tableView(_:canEditRowAt:)))
        let canEditCell = doesDataSourceImplementCanEditRow && dataSource.tableView!(self, canEditRowAt: indexPath)
        if !canEditCell {
            throw Fleet.TableViewError.rejectedAction(at: indexPath, reason: "Table view data source does not allow editing of that row.")
        }

        let editActions = delegate.tableView!(self, editActionsForRowAt: indexPath)
        let actionOpt = editActions?.first() { element in
            return element.title == title
        }

        guard let action = actionOpt else {
            throw Fleet.TableViewError.cellActionDoesNotExist(at: indexPath, title: title)
        }

        delegate.tableView?(self, willBeginEditingRowAt: indexPath)
        action.handler!(action, indexPath)
        delegate.tableView?(self, didEndEditingRowAt: indexPath)
    }
}
