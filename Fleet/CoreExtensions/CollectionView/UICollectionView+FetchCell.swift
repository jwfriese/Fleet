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
        do {
            return try fetchCellOrThrow(at: indexPath)
        } catch let failure as FleetFailure {
            FleetError(Fleet.CollectionViewError.legacy(failure)).raise()
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
        return UICollectionViewCell()
    }

    /**
     Like `fetchCell(at:)`, but reports failures as Swift errors instead of raising an `NSException`.

     - throws:
     A `FleetFailure` of kind `.invalidSetup` without a data source, `.invalidInput` when the
     section or item does not exist, or `.unavailableInteraction` when UIKit cannot display the cell.
     */
    public func fetchCellOrThrow(at indexPath: IndexPath) throws -> UICollectionViewCell {
        let action = "fetch cell"
        // UIKit's `section`/`item` accessors trap when the path has fewer than two components.
        guard indexPath.count >= 2 else {
            throw FleetFailure(kind: .invalidInput, action: action,
                               target: "UICollectionView index path \(Array(indexPath))",
                               state: "the index path has \(indexPath.count) component(s)",
                               reason: "A collection view index path needs a section and an item.")
        }
        let target = "UICollectionView item \(indexPath.item) in section \(indexPath.section)"

        guard self.dataSource != nil else {
            throw FleetFailure(kind: .invalidSetup, action: action, target: target,
                               state: "the collection view has no data source",
                               reason: Fleet.CollectionViewError.dataSourceRequired(userAction: "fetch cells").errorMessage)
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

        layoutIfNeeded()
        if cellForItem(at: indexPath) == nil {
            scrollToItem(at: indexPath, at: [], animated: false)
            layoutIfNeeded()
        }

        guard let cell = cellForItem(at: indexPath) else {
            throw FleetFailure(kind: .unavailableInteraction, action: action, target: target,
                               state: "UIKit did not produce a cell after scrolling to the item",
                               reason: Fleet.CollectionViewError.cellUnavailable(at: indexPath).errorMessage)
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

    /**
     Like `fetchCell(at:asType:)`, but reports failures as Swift errors instead of raising an `NSException`.

     - throws:
     The failures of `fetchCellOrThrow(at:)`, or a `FleetFailure` of kind `.invalidInput` if the cell is not of the given type.
     */
    public func fetchCellOrThrow<T>(at indexPath: IndexPath, asType type: T.Type) throws -> T where T: UICollectionViewCell {
        let cell = try fetchCellOrThrow(at: indexPath)
        guard let castedCell = cell as? T else {
            throw FleetFailure(kind: .invalidInput, action: "fetch cell",
                               target: "UICollectionView item \(indexPath.item) in section \(indexPath.section)",
                               state: "the cell is of type `\(Swift.type(of: cell))`",
                               reason: Fleet.CollectionViewError.mismatchedCellType(at: indexPath, foundType: Swift.type(of: cell), requestedType: type).errorMessage)
        }
        return castedCell
    }
}
