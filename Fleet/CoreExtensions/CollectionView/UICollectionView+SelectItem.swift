import UIKit

extension UICollectionView {
    /**
     Mimic a user tap on the item at the given index path in the collection view.
     Unlike UICollectionView's selectItem(at:animated:scrollPosition:) method, this
     method fires the collection view's delegate callbacks.

     When the collection view does not allow multiple selection, any previously selected
     item is deselected first (if the delegate allows it). With multiple selection, tapping a selected item deselects it. The delegate's
     `collectionView(_:shouldSelectItemAt:)` and `collectionView(_:shouldDeselectItemAt:)`
     are honored; a rejection of either the selection or of the deselection of a previously selected
     item leaves the selection unchanged.

     This does not exercise hit testing or highlight callbacks.

     - parameters:
        - at: The index path to attempt to tap

     - throws:
     A `FleetError` if there is no item at the given index path, if the collection view
     does not have a data source, or if the collection view does not allow selection
     (`allowsSelection == false`).
     */
    public func selectItem(at indexPath: IndexPath) {
        do {
            _ = try selectItemOrThrow(at: indexPath)
        } catch let failure as FleetFailure {
            FleetError(Fleet.CollectionViewError.legacy(failure)).raise()
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
    }

    /**
     Like `selectItem(at:)`, but reports failures as Swift errors instead of raising an `NSException`.
     This is the recoverable form that the next major release adopts for `selectItem(at:)`.

     - parameters:
        - at: The index path to attempt to tap

     - throws:
     A `FleetFailure` of kind `.invalidSetup` without a data source, `.unavailableInteraction`
     when `allowsSelection` is `false`, or `.invalidInput` when the section or item does not exist.

     - returns:
     `.performed`, or `.refusedByDelegate` when `shouldSelectItemAt` or a needed `shouldDeselectItemAt`
     returned `false`. A delegate veto is not an error and leaves the selection unchanged.
     */
    @discardableResult
    public func selectItemOrThrow(at indexPath: IndexPath) throws -> FleetInteractionOutcome {
        let action = "select item"
        let target = "UICollectionView item \(indexPath.item) in section \(indexPath.section)"

        guard let _ = self.dataSource else {
            throw FleetFailure(kind: .invalidSetup, action: action, target: target,
                               state: "the collection view has no data source",
                               reason: "Data source required to \(action).")
        }

        guard allowsSelection else {
            throw FleetFailure(kind: .unavailableInteraction, action: action, target: target,
                               state: "allowsSelection is false",
                               reason: "Interaction with item \(indexPath.item) in section \(indexPath.section) rejected: Collection view does not allow selection.")
        }

        if indexPath.section < 0 || numberOfSections <= indexPath.section {
            throw FleetFailure(kind: .invalidInput, action: action, target: target,
                               state: "the collection view has \(numberOfSections) section(s)",
                               reason: "Collection view has no section \(indexPath.section).")
        }

        if indexPath.item < 0 || numberOfItems(inSection: indexPath.section) <= indexPath.item {
            throw FleetFailure(kind: .invalidInput, action: action, target: target,
                               state: "section \(indexPath.section) has \(numberOfItems(inSection: indexPath.section)) item(s)",
                               reason: "Collection view has no item \(indexPath.item) in section \(indexPath.section).")
        }

        if allowsMultipleSelection, (indexPathsForSelectedItems ?? []).contains(indexPath) {
            return deselectItemWithDelegateCallbacks(at: indexPath)
                ? .performed : .refusedByDelegate(method: "collectionView(_:shouldDeselectItemAt:)")
        }

        if let shouldSelect = delegate?.collectionView?(self, shouldSelectItemAt: indexPath), !shouldSelect {
            return .refusedByDelegate(method: "collectionView(_:shouldSelectItemAt:)")
        }

        if !allowsMultipleSelection {
            for selectedIndexPath in indexPathsForSelectedItems ?? [] where selectedIndexPath != indexPath {
                if !deselectItemWithDelegateCallbacks(at: selectedIndexPath) {
                    return .refusedByDelegate(method: "collectionView(_:shouldDeselectItemAt:)")
                }
            }
        }

        selectItem(at: indexPath, animated: false, scrollPosition: [])
        delegate?.collectionView?(self, didSelectItemAt: indexPath)
        return .performed
    }

    private func deselectItemWithDelegateCallbacks(at indexPath: IndexPath) -> Bool {
        if let shouldDeselect = delegate?.collectionView?(self, shouldDeselectItemAt: indexPath), !shouldDeselect {
            return false
        }
        deselectItem(at: indexPath, animated: false)
        delegate?.collectionView?(self, didDeselectItemAt: indexPath)
        return true
    }
}
