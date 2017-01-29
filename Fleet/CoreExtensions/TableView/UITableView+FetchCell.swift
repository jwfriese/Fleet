import UIKit

extension UITableView {
    /**
     Fetches the cell at the given index path from the table view.

     - parameters:
        - indexPath: The index path of the cell to fetch

     - throws:
     A `Fleet.TableViewError` if the table view does not have a data source or if the given
     index path does not exist on the table view.
     */
    public func fetchCell(at indexPath: IndexPath) throws -> UITableViewCell {
        guard let dataSource = self.dataSource else {
            throw Fleet.TableViewError.dataSourceRequired(userAction: "fetch cells")
        }
        if indexPath.section < 0 || numberOfSections <= indexPath.section {
            throw Fleet.TableViewError.sectionDoesNotExist(sectionNumber: indexPath.section)
        }
        if indexPath.row < 0 || numberOfRows(inSection: indexPath.section) <= indexPath.row {
            throw Fleet.TableViewError.rowDoesNotExist(at: indexPath)
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
     A `Fleet.TableViewError` if the table view does not have a data source, if the given
     index path does not exist on the table view, or if the cast to the given type fails.
     */
    public func fetchCell<T>(at indexPath: IndexPath, asType type: T.Type) throws -> T where T: UITableViewCell {
        let cell = try fetchCell(at: indexPath)
        guard let castedCell = cell as? T else {
            throw Fleet.TableViewError.mismatchedCellType(at: indexPath, foundType: type(of: cell), requestedType: type)
        }
        return castedCell
    }
}
