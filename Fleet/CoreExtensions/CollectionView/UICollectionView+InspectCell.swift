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
        do {
            return try displayedCellOrThrow(at: indexPath)
        } catch let failure as FleetFailure {
            FleetError(Fleet.CollectionViewError.legacy(failure)).raise()
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
        return nil
    }

    /**
     Like `displayedCell(at:)`, but reports failures as Swift errors instead of raising an `NSException`.
     Inspection stays read-only: it never lays out, scrolls, dequeues, or calls the data source.

     - throws:
     A `FleetFailure` of kind `.invalidSetup` without a data source, or `.invalidInput` when the index path
     is malformed or the section or item does not exist.

     - returns:
     The live visible cell, or `nil` if the valid item is not currently visible.
     */
    public func displayedCellOrThrow(at indexPath: IndexPath) throws -> UICollectionViewCell? {
        try validateItemExistsOrThrow(at: indexPath, action: "inspect cell", userAction: "inspect cells")
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
        do {
            return try displayedCellOrThrow(at: indexPath, asType: type)
        } catch let failure as FleetFailure {
            FleetError(Fleet.CollectionViewError.legacy(failure)).raise()
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
        return T()
    }

    /**
     Like `displayedCell(at:asType:)`, but reports failures as Swift errors instead of raising an `NSException`.

     - throws:
     The failures of `displayedCellOrThrow(at:)`, or a `FleetFailure` of kind `.invalidInput` if the displayed cell is not of the given type.
     */
    public func displayedCellOrThrow<T>(at indexPath: IndexPath, asType type: T.Type) throws -> T? where T: UICollectionViewCell {
        guard let cell = try displayedCellOrThrow(at: indexPath) else { return nil }
        guard let castedCell = cell as? T else {
            throw FleetFailure(kind: .invalidInput, action: "inspect cell",
                               target: "UICollectionView item \(indexPath.item) in section \(indexPath.section)",
                               state: "the cell is of type `\(Swift.type(of: cell))`",
                               reason: Fleet.CollectionViewError.mismatchedCellType(at: indexPath, foundType: Swift.type(of: cell), requestedType: type).errorMessage)
        }
        return castedCell
    }

    /// Throws a `FleetFailure` unless there is a data source and the item exists.
    internal func validateItemExistsOrThrow(at indexPath: IndexPath, action: String, userAction: String) throws {
        // UIKit's `section`/`item` accessors trap when the path has fewer than two components.
        guard indexPath.count >= 2 else {
            throw FleetFailure(kind: .invalidInput, action: action,
                               target: "UICollectionView index path \(Array(indexPath))",
                               state: "the index path has \(indexPath.count) component(s)",
                               reason: Fleet.CollectionViewError.invalidIndexPath(indexPath).errorMessage)
        }
        let target = "UICollectionView item \(indexPath.item) in section \(indexPath.section)"
        guard dataSource != nil else {
            throw FleetFailure(kind: .invalidSetup, action: action, target: target,
                               state: "the collection view has no data source",
                               reason: Fleet.CollectionViewError.dataSourceRequired(userAction: userAction).errorMessage)
        }
        if indexPath.section < 0 || numberOfSections <= indexPath.section {
            throw FleetFailure(kind: .invalidInput, action: action, target: target,
                               state: "the collection view has \(numberOfSections) section(s)",
                               reason: Fleet.CollectionViewError.sectionDoesNotExist(sectionNumber: indexPath.section).errorMessage)
        }
        if indexPath.item < 0 || numberOfItems(inSection: indexPath.section) <= indexPath.item {
            throw FleetFailure(kind: .invalidInput, action: action, target: target,
                               state: "section \(indexPath.section) has \(numberOfItems(inSection: indexPath.section)) item(s)",
                               reason: Fleet.CollectionViewError.itemDoesNotExist(at: indexPath).errorMessage)
        }
    }
}
