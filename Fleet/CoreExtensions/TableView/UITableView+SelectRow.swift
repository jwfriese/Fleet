import UIKit

extension UITableView {
    /**
     Mimic a user tap on the cell at the given index path in the table view.
     Unlike UITableView's selectRow(at:animated:scrollPosition:) method, this
     method fires the table view's hooked-in delegate call backs and sends a
     notification.

     - parameters:
        - at: The index path to attempt to tap

     - throws:
     A `FleetError` if there is no cell at the given index path
     or if the table view does not allow selection ('allowsSelection' == false)
     */
    public func selectRow(at indexPath: IndexPath) {
        guard let _ = self.dataSource else {
            FleetError(Fleet.TableViewError.dataSourceRequired(userAction: "select cell row")).raise()
            return
        }

        guard allowsSelection else {
            FleetError(Fleet.TableViewError.rejectedAction(at: indexPath, reason: "Table view does not allow selection.")).raise()
            return
        }

        guard fleet_validateExistingRow(at: indexPath) else { return }

        let hasDelegate = delegate != nil

        // Stage delegate redirections and validate them all before mutating selection
        // or dispatching any did(De)Select callbacks.
        var indexPathToDeselect: IndexPath?
        let doesDelegateImplementWillDeselect = hasDelegate && delegate!.responds(to: #selector(UITableViewDelegate.tableView(_:willDeselectRowAt:)))
        if doesDelegateImplementWillDeselect, let selectedRowIndexPath = indexPathForSelectedRow {
            if let redirected = delegate!.tableView!(self, willDeselectRowAt: selectedRowIndexPath) {
                guard fleet_validateExistingRow(at: redirected) else { return }
                indexPathToDeselect = redirected
            }
        }

        var indexPathToSelect: IndexPath? = indexPath
        let doesDelegateImplementWillSelect = hasDelegate && delegate!.responds(to: #selector(UITableViewDelegate.tableView(_:willSelectRowAt:)))
        if doesDelegateImplementWillSelect {
            indexPathToSelect = delegate!.tableView!(self, willSelectRowAt: indexPath)
            if let redirected = indexPathToSelect {
                guard fleet_validateExistingRow(at: redirected) else { return }
            }
        }

        if let indexPathToDeselect = indexPathToDeselect {
            deselectRow(at: indexPathToDeselect, animated: false)
            NotificationCenter.default.post(name: UITableView.selectionDidChangeNotification, object: nil)
            delegate?.tableView?(self, didDeselectRowAt: indexPathToDeselect)
        }

        guard let indexPathToSelect = indexPathToSelect else { return }

        selectRow(at: indexPathToSelect, animated: false, scrollPosition: .none)
        NotificationCenter.default.post(name: UITableView.selectionDidChangeNotification, object: nil)

        delegate?.tableView?(self, didSelectRowAt: indexPathToSelect)
    }
}
