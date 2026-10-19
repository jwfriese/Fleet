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
        do {
            _ = try deselectItemOrThrow(at: indexPath)
        } catch let failure as FleetFailure {
            FleetError(Fleet.CollectionViewError.legacy(failure)).raise()
        } catch {
            FleetError(Fleet.InternalError.unrecoverable(details: "\(error)")).raise()
        }
    }

    /**
     Like `deselectItem(at:)`, but reports failures as Swift errors instead of raising an `NSException`.
     Failed validation neither changes the selection nor calls the delegate.

     - throws:
     A `FleetFailure` of kind `.invalidSetup` without a data source, `.invalidInput` when the index path is
     malformed or the section or item does not exist, or `.unavailableInteraction` when `allowsSelection` is
     `false` or the item is not selected.

     - returns:
     `.performed`, or `.refusedByDelegate` when `shouldDeselectItemAt` returned `false`. A delegate veto is
     not an error and leaves the item selected.
     */
    @discardableResult
    public func deselectItemOrThrow(at indexPath: IndexPath) throws -> FleetInteractionOutcome {
        let action = "deselect item"
        try validateItemExistsOrThrow(at: indexPath, action: action, userAction: "deselect item")
        let target = "UICollectionView item \(indexPath.item) in section \(indexPath.section)"

        guard allowsSelection else {
            throw FleetFailure(kind: .unavailableInteraction, action: action, target: target,
                               state: "allowsSelection is false",
                               reason: Fleet.CollectionViewError.rejectedAction(at: indexPath, reason: "Collection view does not allow selection.").errorMessage)
        }

        guard (indexPathsForSelectedItems ?? []).contains(indexPath) else {
            throw FleetFailure(kind: .unavailableInteraction, action: action, target: target,
                               state: "the item is not selected",
                               reason: Fleet.CollectionViewError.rejectedAction(at: indexPath, reason: "Item is not selected.").errorMessage)
        }

        return deselectItemWithDelegateCallbacks(at: indexPath)
            ? .performed : .refusedByDelegate(method: "collectionView(_:shouldDeselectItemAt:)")
    }
}
