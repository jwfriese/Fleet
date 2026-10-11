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
        guard let dataSource = self.dataSource else {
            FleetError(Fleet.TableViewError.dataSourceRequired(userAction: "fetch cells")).raise()
            return UITableViewCell()
        }
        if indexPath.section < 0 || numberOfSections <= indexPath.section {
            FleetError(Fleet.TableViewError.sectionDoesNotExist(sectionNumber: indexPath.section)).raise()
            return UITableViewCell()
        }
        if indexPath.row < 0 || numberOfRows(inSection: indexPath.section) <= indexPath.row {
            FleetError(Fleet.TableViewError.rowDoesNotExist(at: indexPath)).raise()
            return UITableViewCell()
        }

        return dataSource.tableView(self, cellForRowAt: indexPath)
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
        let cell = fetchCell(at: indexPath)
        guard let castedCell = cell as? T else {
            FleetError(Fleet.TableViewError.mismatchedCellType(at: indexPath, foundType: Swift.type(of: cell), requestedType: type)).raise()
            return T()
        }
        return castedCell
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
        guard self.dataSource != nil else {
            FleetError(Fleet.TableViewError.dataSourceRequired(userAction: "fetch displayed cells")).raise()
            return UITableViewCell()
        }
        if indexPath.section < 0 || numberOfSections <= indexPath.section {
            FleetError(Fleet.TableViewError.sectionDoesNotExist(sectionNumber: indexPath.section)).raise()
            return UITableViewCell()
        }
        if indexPath.row < 0 || numberOfRows(inSection: indexPath.section) <= indexPath.row {
            FleetError(Fleet.TableViewError.rowDoesNotExist(at: indexPath)).raise()
            return UITableViewCell()
        }
        guard let cell = cellForRow(at: indexPath) else {
            FleetError(Fleet.TableViewError.cellNotDisplayed(at: indexPath)).raise()
            return UITableViewCell()
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
        let cell = fetchDisplayedCell(at: indexPath)
        guard let castedCell = cell as? T else {
            FleetError(Fleet.TableViewError.mismatchedCellType(at: indexPath, foundType: Swift.type(of: cell), requestedType: type)).raise()
            return T()
        }
        return castedCell
    }
}
