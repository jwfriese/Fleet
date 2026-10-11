import UIKit

extension UITableView {
    /**
     Mimic a user tap on the row at the given index path in the table view.
     Unlike UITableView's selectRow(at:animated:scrollPosition:) method, this
     method fires the table view's hooked-in delegate call backs and sends a
     notification.

     Callback order for a tap that changes selection in single-selection mode:
     `willSelectRowAt`, `willDeselectRowAt` (for the previously selected row),
     `didDeselectRowAt`, `didSelectRowAt`. Delegate methods the delegate does not
     implement are skipped. If `willSelectRowAt` returns `nil`, nothing changes. If
     it redirects, the redirected index path is validated before any state changes
     and is the path that is selected and reported to `didSelectRowAt`. If
     `willDeselectRowAt` returns `nil`, no deselection callback or notification is
     sent for that row. `UITableView.selectionDidChangeNotification` is posted, with
     the table view as its object, after each selection or deselection.

     Supported modes:
     - Single selection: selecting another row deselects the previous one; tapping
       the already selected row reports `willSelectRowAt`/`didSelectRowAt` again
       and leaves it selected.
     - Multiple selection (`allowsMultipleSelection`, or
       `allowsMultipleSelectionDuringEditing` while `isEditing`): other selected rows
       stay selected; tapping an already selected row deselects it, with
       `willDeselectRowAt`/`didDeselectRowAt`.
     - While `isEditing`, selection requires `allowsSelectionDuringEditing`;
       otherwise it requires `allowsSelection`.

     Not simulated: hit testing, highlighting (`shouldHighlightRowAt`), scrolling,
     and cell-level editing controls.

     - parameters:
        - at: The index path to attempt to tap

     - throws:
     A `FleetError` if there is no row at the given index path (including a
     delegate-redirected one), or if the table view does not allow selection in its
     current mode.
     */
    public func selectRow(at indexPath: IndexPath) {
        guard let _ = self.dataSource else {
            FleetError(Fleet.TableViewError.dataSourceRequired(userAction: "select cell row")).raise()
            return
        }

        let selectionAllowed = isEditing ? allowsSelectionDuringEditing : allowsSelection
        guard selectionAllowed else {
            let reason = isEditing ? "Table view does not allow selection during editing." : "Table view does not allow selection."
            FleetError(Fleet.TableViewError.rejectedAction(at: indexPath, reason: reason)).raise()
            return
        }

        guard fleet_validateExistingRow(at: indexPath) else { return }

        var indexPathToSelect = indexPath
        if let delegate = delegate, delegate.responds(to: #selector(UITableViewDelegate.tableView(_:willSelectRowAt:))) {
            guard let redirected = delegate.tableView!(self, willSelectRowAt: indexPath) else {
                return
            }
            guard fleet_validateExistingRow(at: redirected) else { return }
            indexPathToSelect = redirected
        }

        let multipleSelection = isEditing ? allowsMultipleSelectionDuringEditing : allowsMultipleSelection
        let alreadySelected = indexPathsForSelectedRows?.contains(indexPathToSelect) ?? false

        if multipleSelection && alreadySelected {
            deselectRowFiringCallbacks(at: indexPathToSelect)
            return
        }

        if !multipleSelection {
            for previous in indexPathsForSelectedRows ?? [] where previous != indexPathToSelect {
                deselectRowFiringCallbacks(at: previous)
            }
        }

        selectRow(at: indexPathToSelect, animated: false, scrollPosition: .none)
        NotificationCenter.default.post(name: UITableView.selectionDidChangeNotification, object: self)

        delegate?.tableView?(self, didSelectRowAt: indexPathToSelect)
    }

    private func deselectRowFiringCallbacks(at indexPath: IndexPath) {
        var indexPathToDeselect = indexPath
        if let delegate = delegate, delegate.responds(to: #selector(UITableViewDelegate.tableView(_:willDeselectRowAt:))) {
            guard let redirected = delegate.tableView!(self, willDeselectRowAt: indexPath) else { return }
            indexPathToDeselect = redirected
        }
        deselectRow(at: indexPathToDeselect, animated: false)
        NotificationCenter.default.post(name: UITableView.selectionDidChangeNotification, object: self)
        delegate?.tableView?(self, didDeselectRowAt: indexPathToDeselect)
    }
}
