import UIKit

extension UITableView {
    /**
     Mimic a user taking an edit action on the cell at the given index path in
     the table view.

     - parameters:
        - title: The title of the edit action to take
        - at: The index path at which to attempt to take this action

     - throws:
     A `FleetError` is there is no cell at the given index path, if the data source
     does not allow editing of the given index path, or if there is no edit action with the
     given title on the cell.
     */
    public func selectCellAction(withTitle title: String, at indexPath: IndexPath) throws {
        guard let dataSource = dataSource else {
            FleetError(Fleet.TableViewError.dataSourceRequired(userAction: "select cell action")).raise()
            return
        }

        guard let delegate = delegate else {
            FleetError(Fleet.TableViewError.delegateRequired(userAction: "select cell action")).raise()
            return
        }

        if !delegate.responds(to: #selector(UITableViewDelegate.tableView(_:editActionsForRowAt:))) {
            FleetError(Fleet.TableViewError.incompleteDelegate(required: "UITableViewDelegate.tableView(_:editActionsForRowAt:)", userAction: "select cell action")).raise()
            return
        }

        let sectionCount = numberOfSections
        if indexPath.section >= sectionCount {
            FleetError(Fleet.TableViewError.sectionDoesNotExist(sectionNumber: indexPath.section)).raise()
            return
        }

        let rowCount = numberOfRows(inSection: indexPath.section)
        if indexPath.row >= rowCount {
            FleetError(Fleet.TableViewError.rowDoesNotExist(at: indexPath)).raise()
            return
        }

        let doesDataSourceImplementCanEditRow = dataSource.responds(to: #selector(UITableViewDataSource.tableView(_:canEditRowAt:)))
        let canEditCell = doesDataSourceImplementCanEditRow && dataSource.tableView!(self, canEditRowAt: indexPath)
        if !canEditCell {
            FleetError(Fleet.TableViewError.rejectedAction(at: indexPath, reason: "Table view data source does not allow editing of that row.")).raise()
            return
        }

        let editActions = delegate.tableView!(self, editActionsForRowAt: indexPath)
        let actionOpt = editActions?.first() { element in
            return element.title == title
        }

        guard let action = actionOpt else {
            FleetError(Fleet.TableViewError.cellActionDoesNotExist(at: indexPath, title: title)).raise()
            return
        }

        delegate.tableView?(self, willBeginEditingRowAt: indexPath)
        action.handler!(action, indexPath)
        delegate.tableView?(self, didEndEditingRowAt: indexPath)
    }
}
