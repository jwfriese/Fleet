import UIKit

extension UITableView {
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

    public func fetchCell<T>(at indexPath: IndexPath, asType type: T.Type) throws -> T where T: UITableViewCell {
        let cell = try fetchCell(at: indexPath)
        guard let castedCell = cell as? T else {
            throw Fleet.TableViewError.mismatchedCellType(at: indexPath, foundType: type(of: cell), requestedType: type)
        }
        return castedCell
    }
}
