import UIKit

extension UICollectionView {
    /**
     Fetches the cell at the given index path from the collection view.

     UIKit only allows a collection view to build cells during its own layout pass, so this
     lays out the collection view and, if the item is not currently on screen, scrolls
     (without animation) to the item first. The scroll position therefore may change.

     - parameters:
        - indexPath: The index path of the cell to fetch

     - throws:
     A `FleetError` if the collection view does not have a data source if the given
     index path does not exist on the collection view, or if the cell cannot be displayed.
     */
    public func fetchCell(at indexPath: IndexPath) -> UICollectionViewCell {
        guard self.dataSource != nil else {
            FleetError(Fleet.CollectionViewError.dataSourceRequired(userAction: "fetch cells")).raise()
            return UICollectionViewCell()
        }
        if indexPath.section < 0 || numberOfSections <= indexPath.section {
            FleetError(Fleet.CollectionViewError.sectionDoesNotExist(sectionNumber: indexPath.section)).raise()
            return UICollectionViewCell()
        }
        if indexPath.item < 0 || numberOfItems(inSection: indexPath.section) <= indexPath.item {
            FleetError(Fleet.CollectionViewError.itemDoesNotExist(at: indexPath)).raise()
            return UICollectionViewCell()
        }

        layoutIfNeeded()
        if cellForItem(at: indexPath) == nil {
            scrollToItem(at: indexPath, at: [], animated: false)
            layoutIfNeeded()
        }

        guard let cell = cellForItem(at: indexPath) else {
            FleetError(Fleet.CollectionViewError.cellUnavailable(at: indexPath)).raise()
            return UICollectionViewCell()
        }
        return cell
    }

    /**
     Fetches the cell at the given index path from the collection view and casts it to the
     given `UICollectionViewCell` subclass.

     - parameters:
        - indexPath: The index path of the cell to fetch
        - type: The type of cell expected to return from the fetch. It must be a kind of `UICollectionViewCell`

     - throws:
     A `FleetError` if the collection view does not have a data source, if the given
     index path does not exist on the collection view, or if the cast to the given type fails.
     */
    public func fetchCell<T>(at indexPath: IndexPath, asType type: T.Type) -> T where T: UICollectionViewCell {
        let cell = fetchCell(at: indexPath)
        guard let castedCell = cell as? T else {
            FleetError(Fleet.CollectionViewError.mismatchedCellType(at: indexPath, foundType: Swift.type(of: cell), requestedType: type)).raise()
            return T()
        }
        return castedCell
    }
}
