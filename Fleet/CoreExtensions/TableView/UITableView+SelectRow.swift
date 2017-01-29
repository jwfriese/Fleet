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
     A `Fleet.TableViewError` if there is no cell at the given index path
     or if the table view does not allow selection ('allowsSelection' == false)
     */
    public func selectRow(at indexPath: IndexPath) throws {
        guard let _ = self.dataSource else {
            throw Fleet.TableViewError.dataSourceRequired(userAction: "select cell row")
        }

        guard allowsSelection else {
            throw Fleet.TableViewError.rejectedAction(at: indexPath, reason: "Table view does not allow selection.")
        }

        let sectionCount = numberOfSections
        if indexPath.section >= sectionCount {
            throw Fleet.TableViewError.sectionDoesNotExist(sectionNumber: indexPath.section)
        }

        let rowCount = numberOfRows(inSection: indexPath.section)
        if indexPath.row >= rowCount {
            throw Fleet.TableViewError.rowDoesNotExist(at: indexPath)
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
                return
            }

            indexPathToSelect = unwrappedIndexPathToSelect
        }

        selectRow(at: indexPath, animated: false, scrollPosition: .none)
        NotificationCenter.default.post(name: NSNotification.Name.UITableViewSelectionDidChange, object: nil)

        delegate?.tableView?(self, didSelectRowAt: indexPathToSelect)
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
