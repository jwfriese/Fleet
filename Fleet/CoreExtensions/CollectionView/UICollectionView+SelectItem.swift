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
        guard let _ = self.dataSource else {
            FleetError(Fleet.CollectionViewError.dataSourceRequired(userAction: "select item")).raise()
            return
        }

        guard allowsSelection else {
            FleetError(Fleet.CollectionViewError.rejectedAction(at: indexPath, reason: "Collection view does not allow selection.")).raise()
            return
        }

        if indexPath.section < 0 || numberOfSections <= indexPath.section {
            FleetError(Fleet.CollectionViewError.sectionDoesNotExist(sectionNumber: indexPath.section)).raise()
            return
        }

        if indexPath.item < 0 || numberOfItems(inSection: indexPath.section) <= indexPath.item {
            FleetError(Fleet.CollectionViewError.itemDoesNotExist(at: indexPath)).raise()
            return
        }

        if allowsMultipleSelection, (indexPathsForSelectedItems ?? []).contains(indexPath) {
            _ = deselectItemWithDelegateCallbacks(at: indexPath)
            return
        }

        if let shouldSelect = delegate?.collectionView?(self, shouldSelectItemAt: indexPath), !shouldSelect {
            return
        }

        if !allowsMultipleSelection {
            for selectedIndexPath in indexPathsForSelectedItems ?? [] where selectedIndexPath != indexPath {
                if !deselectItemWithDelegateCallbacks(at: selectedIndexPath) {
                    return
                }
            }
        }

        selectItem(at: indexPath, animated: false, scrollPosition: [])
        delegate?.collectionView?(self, didSelectItemAt: indexPath)
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
