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

     Use `selectRowOrThrow(at:)` to receive failures as Swift errors and to learn when a
     delegate refused the tap.

     - throws:
     A `FleetError` if there is no row at the given index path (including a
     delegate-redirected one), or if the table view does not allow selection in its
     current mode.
     */
    public func selectRow(at indexPath: IndexPath) {
        fleet_raisingLegacy((), { _ = try selectRowOrThrow(at: indexPath) })
    }

    /**
     Like `selectRow(at:)`, but reports failures as Swift errors instead of raising an
     `NSException`, and reports a delegate refusal as an outcome.

     Every index path involved (the tapped one, a `willSelectRowAt` redirect, and each
     `willDeselectRowAt` redirect) is validated before any selection changes or any `did...`
     callback or notification is sent.

     - parameters:
        - at: The index path to attempt to tap

     - throws:
     A `FleetFailure` of kind `.invalidSetup` without a data source, `.unavailableInteraction`
     when the table view does not allow selection in its current mode, or `.invalidInput`
     when the index path or a delegate-redirected one does not exist.

     - returns:
     `.performed`, or `.refusedByDelegate` when `willSelectRowAt` returned `nil`, or
     `willDeselectRowAt` returned `nil` for a row that a multiple-selection tap would
     deselect. A veto is not an error and leaves the selection unchanged. In single-selection
     mode a `nil` from `willDeselectRowAt` only skips that row's deselection callbacks;
     UIKit's `selectRow` still replaces the selection.
     */
    @discardableResult
    public func selectRowOrThrow(at indexPath: IndexPath) throws -> FleetInteractionOutcome {
        let action = "select row"
        let target = indexPath.count >= 2 ? "UITableView row \(indexPath.row) in section \(indexPath.section)" : "UITableView"

        try fleet_requireDataSource(action: action, userAction: "select cell row", target: target)

        let selectionAllowed = isEditing ? allowsSelectionDuringEditing : allowsSelection
        guard selectionAllowed else {
            let reason = isEditing ? "Table view does not allow selection during editing." : "Table view does not allow selection."
            throw FleetFailure(kind: .unavailableInteraction, action: action, target: target,
                               state: isEditing ? "allowsSelectionDuringEditing is false" : "allowsSelection is false",
                               reason: "Interaction with row \(indexPath.row) in section \(indexPath.section) rejected: \(reason)")
        }

        try fleet_requireExistingRow(at: indexPath, action: action)

        var indexPathToSelect = indexPath
        if let delegate = delegate, delegate.responds(to: #selector(UITableViewDelegate.tableView(_:willSelectRowAt:))) {
            guard let redirected = delegate.tableView!(self, willSelectRowAt: indexPath) else {
                return .refusedByDelegate(method: "tableView(_:willSelectRowAt:)")
            }
            try fleet_requireExistingRow(at: redirected, action: action)
            indexPathToSelect = redirected
        }

        let multipleSelection = isEditing ? allowsMultipleSelectionDuringEditing : allowsMultipleSelection
        let selectedRows = indexPathsForSelectedRows ?? []

        if multipleSelection && selectedRows.contains(indexPathToSelect) {
            guard let deselection = try stageDeselection(of: indexPathToSelect, action: action) else {
                return .refusedByDelegate(method: "tableView(_:willDeselectRowAt:)")
            }
            performDeselection(deselection)
            return .performed
        }

        // Stage every deselection, validating redirects, before anything changes.
        var deselections: [(row: IndexPath, target: IndexPath)] = []
        if !multipleSelection {
            for previous in selectedRows where previous != indexPathToSelect {
                if let staged = try stageDeselection(of: previous, action: action) {
                    deselections.append(staged)
                }
            }
        }

        deselections.forEach(performDeselection)

        selectRow(at: indexPathToSelect, animated: false, scrollPosition: .none)
        NotificationCenter.default.post(name: UITableView.selectionDidChangeNotification, object: self)

        delegate?.tableView?(self, didSelectRowAt: indexPathToSelect)
        return .performed
    }

    /// Asks `willDeselectRowAt` and validates its redirect. Returns `nil` when the delegate vetoed.
    private func stageDeselection(of indexPath: IndexPath, action: String) throws -> (row: IndexPath, target: IndexPath)? {
        var indexPathToDeselect = indexPath
        if let delegate = delegate, delegate.responds(to: #selector(UITableViewDelegate.tableView(_:willDeselectRowAt:))) {
            guard let redirected = delegate.tableView!(self, willDeselectRowAt: indexPath) else { return nil }
            try fleet_requireExistingRow(at: redirected, action: action)
            indexPathToDeselect = redirected
        }
        return (indexPath, indexPathToDeselect)
    }

    private func performDeselection(_ staged: (row: IndexPath, target: IndexPath)) {
        deselectRow(at: staged.target, animated: false)
        NotificationCenter.default.post(name: UITableView.selectionDidChangeNotification, object: self)
        delegate?.tableView?(self, didDeselectRowAt: staged.target)
    }
}
