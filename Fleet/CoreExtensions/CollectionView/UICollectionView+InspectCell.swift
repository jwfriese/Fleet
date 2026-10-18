import UIKit

extension UICollectionView {
    /**
     Returns the cell UIKit is currently displaying for the given index path, or `nil`
     if that item is not currently visible (for example, because it is scrolled off screen
     or is only a prepared, prefetched cell).

     Unlike `fetchCell(at:)`, this never lays out, scrolls, or otherwise mutates the
     collection view. The returned cell is the live instance, so its identity is only
     stable until UIKit reuses it (after scrolling or a reload).

     - parameters:
        - indexPath: The index path of the cell to inspect

     - throws:
     A `FleetError` if the collection view does not have a data source, or if the given
     index path does not exist on the collection view.
     */
    public func displayedCell(at indexPath: IndexPath) -> UICollectionViewCell? {
        guard validateItemExists(at: indexPath, userAction: "inspect cells") else { return nil }
        // `cellForItem(at:)` also returns prepared (prefetched/cached) cells UIKit is not displaying.
        guard indexPathsForVisibleItems.contains(indexPath) else { return nil }
        return cellForItem(at: indexPath)
    }

    /**
     Returns the cell currently displayed for the given index path, cast to the given
     `UICollectionViewCell` subclass, or `nil` if the item has no live cell.

     - parameters:
        - indexPath: The index path of the cell to inspect
        - type: The type of cell expected. It must be a kind of `UICollectionViewCell`

     - throws:
     A `FleetError` if the collection view does not have a data source, if the given
     index path does not exist, or if a displayed cell is not of the requested type.
     */
    public func displayedCell<T>(at indexPath: IndexPath, asType type: T.Type) -> T? where T: UICollectionViewCell {
        guard let cell = displayedCell(at: indexPath) else { return nil }
        guard let castedCell = cell as? T else {
            FleetError(Fleet.CollectionViewError.mismatchedCellType(at: indexPath, foundType: Swift.type(of: cell), requestedType: type)).raise()
            return T()
        }
        return castedCell
    }

    /// Raises a `FleetError` and returns `false` unless there is a data source and the item exists.
    internal func validateItemExists(at indexPath: IndexPath, userAction: String) -> Bool {
        guard dataSource != nil else {
            FleetError(Fleet.CollectionViewError.dataSourceRequired(userAction: userAction)).raise()
            return false
        }
        // UIKit's `section`/`item` accessors trap when the path has fewer than two components.
        guard indexPath.count >= 2 else {
            FleetError(Fleet.CollectionViewError.invalidIndexPath(indexPath)).raise()
            return false
        }
        if indexPath.section < 0 || numberOfSections <= indexPath.section {
            FleetError(Fleet.CollectionViewError.sectionDoesNotExist(sectionNumber: indexPath.section)).raise()
            return false
        }
        if indexPath.item < 0 || numberOfItems(inSection: indexPath.section) <= indexPath.item {
            FleetError(Fleet.CollectionViewError.itemDoesNotExist(at: indexPath)).raise()
            return false
        }
        return true
    }
}
