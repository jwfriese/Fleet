import UIKit

extension UITableView {
    /**
     Fetches the cell at the given index path from the table view by asking the
     data source to configure one (`tableView(_:cellForRowAt:)`). The result is a
     *configured* cell: it is typically a new or reused instance and is **not**
     necessarily the instance the table view is displaying. To inspect the cell
     the table view is actually displaying, use `fetchDisplayedCell(at:)`.

     - parameters:
        - indexPath: The index path of the cell to fetch

     - throws:
     A `FleetError` if the table view does not have a data source or if the given
     index path does not exist on the table view.
     */
    public func fetchCell(at indexPath: IndexPath) -> UITableViewCell {
        fleet_raisingLegacy(UITableViewCell(), { try fetchCellOrThrow(at: indexPath) })
    }

    /// Like `fetchCell(at:)`, but throws a `FleetFailure` (`.invalidSetup` without a data source,
    /// `.invalidInput` for a nonexistent row) instead of raising an `NSException`.
    public func fetchCellOrThrow(at indexPath: IndexPath) throws -> UITableViewCell {
        let action = "fetch cell"
        let target = indexPath.count >= 2 ? "UITableView row \(indexPath.row) in section \(indexPath.section)" : "UITableView"
        try fleet_requireDataSource(action: action, userAction: "fetch cells", target: target)
        try fleet_requireExistingRow(at: indexPath, action: action)
        return dataSource!.tableView(self, cellForRowAt: indexPath)
    }

    /**
     Fetches the cell at the given index path from the table view and casts it to the
     given `UITableViewCell` subclass.

     - parameters:
        - indexPath: The index path of the cell to fetch
        - type: The type of cell expected to return from the fetch. It must be a kind of `UITableViewCell`

     - throws:
     A `FleetError` if the table view does not have a data source, if the given
     index path does not exist on the table view, or if the cast to the given type fails.
     */
    public func fetchCell<T>(at indexPath: IndexPath, asType type: T.Type) -> T where T: UITableViewCell {
        fleet_raisingLegacy(T(), { try fetchCellOrThrow(at: indexPath, asType: type) })
    }

    /// Like `fetchCell(at:asType:)`, but throws a `FleetFailure` (`.invalidInput` on a type mismatch).
    public func fetchCellOrThrow<T>(at indexPath: IndexPath, asType type: T.Type) throws -> T where T: UITableViewCell {
        let cell = try fetchCellOrThrow(at: indexPath)
        return try fleet_cast(cell, at: indexPath, to: type, action: "fetch cell")
    }

    /**
     Fetches the cell the table view is actually displaying at the given index path.
     Unlike `fetchCell(at:)`, this does not ask the data source for a cell; it returns
     the displayed instance (`cellForRow(at:)`), so reuse and layout state are preserved.

     Only rows that are currently laid out are displayed. Offscreen rows, and rows of
     a table view that has not yet been laid out, are not; call `layoutIfNeeded()`
     first when necessary.

     - parameters:
        - indexPath: The index path of the displayed cell to fetch

     - throws:
     A `FleetError` if the table view does not have a data source, if the given
     index path does not exist on the table view, or if the row is not displayed.
     */
    public func fetchDisplayedCell(at indexPath: IndexPath) -> UITableViewCell {
        fleet_raisingLegacy(UITableViewCell(), { try fetchDisplayedCellOrThrow(at: indexPath) })
    }

    /// Like `fetchDisplayedCell(at:)`, but throws a `FleetFailure` (`.invalidSetup`, `.invalidInput`,
    /// or `.unavailableInteraction` when the row is not in `indexPathsForVisibleRows`).
    public func fetchDisplayedCellOrThrow(at indexPath: IndexPath) throws -> UITableViewCell {
        let action = "fetch displayed cell"
        let target = indexPath.count >= 2 ? "UITableView row \(indexPath.row) in section \(indexPath.section)" : "UITableView"
        try fleet_requireDataSource(action: action, userAction: "fetch displayed cells", target: target)
        try fleet_requireExistingRow(at: indexPath, action: action)
        // `cellForRow(at:)` can also return prepared cells that are retained but offscreen,
        // so require the row to be among the visible rows too.
        guard (indexPathsForVisibleRows ?? []).contains(indexPath), let cell = cellForRow(at: indexPath) else {
            throw FleetFailure(kind: .unavailableInteraction, action: action, target: target,
                               state: "the row is not among the table view's visible rows",
                               reason: "Cell at row \(indexPath.row) in section \(indexPath.section) is not currently displayed by the table view.")
        }
        return cell
    }

    /**
     Fetches the cell the table view is actually displaying at the given index path
     and casts it to the given `UITableViewCell` subclass.

     - parameters:
        - indexPath: The index path of the displayed cell to fetch
        - type: The type of cell expected. It must be a kind of `UITableViewCell`

     - throws:
     A `FleetError` under the conditions of `fetchDisplayedCell(at:)`, or if the cast fails.
     */
    public func fetchDisplayedCell<T>(at indexPath: IndexPath, asType type: T.Type) -> T where T: UITableViewCell {
        fleet_raisingLegacy(T(), { try fetchDisplayedCellOrThrow(at: indexPath, asType: type) })
    }

    /// Like `fetchDisplayedCell(at:asType:)`, but throws a `FleetFailure`.
    public func fetchDisplayedCellOrThrow<T>(at indexPath: IndexPath, asType type: T.Type) throws -> T where T: UITableViewCell {
        let cell = try fetchDisplayedCellOrThrow(at: indexPath)
        return try fleet_cast(cell, at: indexPath, to: type, action: "fetch displayed cell")
    }

    private func fleet_cast<T>(_ cell: UITableViewCell, at indexPath: IndexPath, to type: T.Type, action: String) throws -> T where T: UITableViewCell {
        guard let castedCell = cell as? T else {
            throw FleetFailure(kind: .invalidInput, action: action,
                               target: "UITableView row \(indexPath.row) in section \(indexPath.section)",
                               state: "the cell is a \(Swift.type(of: cell))",
                               reason: "Cell at row \(indexPath.row) in section \(indexPath.section) is of type `\(Swift.type(of: cell))` (wanted `\(type)`).")
        }
        return castedCell
    }
}
