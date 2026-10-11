import UIKit

extension UICollectionView {
    /**
     Returns the cell UIKit is currently displaying for the given index path, or `nil`
     if that item has no live cell (for example, because it is scrolled off screen).

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

    /**
     Asks the collection view's data source to configure a cell for the given index path,
     whether or not the item is on screen.

     This calls `collectionView(_:cellForItemAt:)` directly, which is also how
     `UICollectionViewDiffableDataSource` calls its cell provider. The result is a cell
     dequeued from the collection view's reuse queue: UIKit may attach it to the collection
     view as a subview, but it is not laid out, is not tracked as the item's displayed cell
     (`cellForItem(at:)` and `displayedCell(at:)` do not return it), and is not the cell
     returned by `fetchCell(at:)`. Calling this repeatedly may invoke data source side effects each time.
     The collection view's registered cell classes (or nibs) must be able to supply the
     reuse identifier the data source uses.

     - parameters:
        - indexPath: The index path to configure a cell for

     - throws:
     A `FleetError` if the collection view does not have a data source or the given
     index path does not exist.
     */
    public func configuredCell(at indexPath: IndexPath) -> UICollectionViewCell {
        guard validateItemExists(at: indexPath, userAction: "configure cells"), let dataSource = self.dataSource else {
            return UICollectionViewCell()
        }
        return dataSource.collectionView(self, cellForItemAt: indexPath)
    }

    /**
     Asks the data source to configure a cell for the given index path and casts it to the
     given `UICollectionViewCell` subclass. See `configuredCell(at:)`.

     - parameters:
        - indexPath: The index path to configure a cell for
        - type: The type of cell expected. It must be a kind of `UICollectionViewCell`

     - throws:
     A `FleetError` if the collection view does not have a data source, if the given
     index path does not exist, or if the cast to the given type fails.
     */
    public func configuredCell<T>(at indexPath: IndexPath, asType type: T.Type) -> T where T: UICollectionViewCell {
        let cell = configuredCell(at: indexPath)
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
