import UIKit

extension UITableView {
    /**
     Fetches the cell at the given index path from the table view.

     - parameters:
        - indexPath: The index path of the cell to fetch

     - throws:
     A `FleetError` if the table view does not have a data source or if the given
     index path does not exist on the table view.
     */
    public func fetchCell(at indexPath: IndexPath) throws -> UITableViewCell {
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
    public func fetchCell<T>(at indexPath: IndexPath, asType type: T.Type) throws -> T where T: UITableViewCell {
        let cell = try fetchCell(at: indexPath)
        guard let castedCell = cell as? T else {
            FleetError(Fleet.TableViewError.mismatchedCellType(at: indexPath, foundType: type(of: cell), requestedType: type)).raise()
            return T()
        }
        return castedCell
    }
}
