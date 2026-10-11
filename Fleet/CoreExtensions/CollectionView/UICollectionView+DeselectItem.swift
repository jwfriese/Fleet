import UIKit

extension UICollectionView {
    /**
     Mimic the deselection of the item at the given index path, running the delegate's
     `collectionView(_:shouldDeselectItemAt:)` and, if it allows it,
     `collectionView(_:didDeselectItemAt:)`. Unlike UICollectionView's
     `deselectItem(at:animated:)`, this fires the delegate callbacks.

     A user cannot deselect an item by tapping it unless the collection view allows multiple
     selection (which `selectItem(at:)` mimics); this helper deselects in either mode.
     If the delegate refuses, the item stays selected and no error is raised.

     - parameters:
        - at: The index path of the selected item to deselect

     - throws:
     A `FleetError` if there is no item at the given index path, if the collection view
     does not have a data source, if the collection view does not allow selection, or if
     the item is not currently selected.
     */
    public func deselectItem(at indexPath: IndexPath) {
        guard validateItemExists(at: indexPath, userAction: "deselect item") else { return }

        guard allowsSelection else {
            FleetError(Fleet.CollectionViewError.rejectedAction(at: indexPath, reason: "Collection view does not allow selection.")).raise()
            return
        }

        guard (indexPathsForSelectedItems ?? []).contains(indexPath) else {
            FleetError(Fleet.CollectionViewError.rejectedAction(at: indexPath, reason: "Item is not selected.")).raise()
            return
        }

        _ = deselectItemWithDelegateCallbacks(at: indexPath)
    }
}
