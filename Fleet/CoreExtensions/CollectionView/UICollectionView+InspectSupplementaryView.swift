import UIKit

extension UICollectionView {
    /**
     Returns the supplementary view (header, footer, or another element kind) UIKit is currently
     displaying for the given kind and index path, or `nil` if no matching view is displayed.

     Like `displayedCell(at:)`, this never lays out, scrolls, calls the data source's
     supplementary-view provider, or dequeues a view. The returned view is the live instance;
     UIKit may reuse it after scrolling or a reload.

     A supplementary index path identifies the section and the element's index within it (for a
     section header or footer, the item is normally `0`). It is validated independently of the
     section's item count, so a header can be inspected in an empty section.

     - throws:
     A `FleetFailure` of kind `.invalidSetup` without a data source, or `.invalidInput` for an empty
     element kind, an index path with fewer than two components, or a missing section or negative index.
     A valid request for a view that is not currently displayed returns `nil` instead.
     */
    public func displayedSupplementaryViewOrThrow(ofKind elementKind: String, at indexPath: IndexPath) throws -> UICollectionReusableView? {
        let action = "inspect supplementary view"
        guard indexPath.count >= 2 else {
            throw FleetFailure(kind: .invalidInput, action: action,
                               target: "UICollectionView index path \(Array(indexPath))",
                               state: "the index path has \(indexPath.count) component(s)",
                               reason: Fleet.CollectionViewError.invalidIndexPath(indexPath).errorMessage)
        }
        let target = "UICollectionView supplementary view `\(elementKind)` \(indexPath.item) in section \(indexPath.section)"
        guard dataSource != nil else {
            throw FleetFailure(kind: .invalidSetup, action: action, target: target,
                               state: "the collection view has no data source",
                               reason: Fleet.CollectionViewError.dataSourceRequired(userAction: "inspect supplementary views").errorMessage)
        }
        guard !elementKind.isEmpty else {
            throw FleetFailure(kind: .invalidInput, action: action, target: target,
                               state: "the element kind is empty",
                               reason: "Pass the supplementary element kind, such as UICollectionView.elementKindSectionHeader.")
        }
        if indexPath.section < 0 || numberOfSections <= indexPath.section {
            throw FleetFailure(kind: .invalidInput, action: action, target: target,
                               state: "the collection view has \(numberOfSections) section(s)",
                               reason: Fleet.CollectionViewError.sectionDoesNotExist(sectionNumber: indexPath.section).errorMessage)
        }
        if indexPath.item < 0 {
            throw FleetFailure(kind: .invalidInput, action: action, target: target,
                               state: "the supplementary index is negative",
                               reason: "A supplementary view index must not be negative.")
        }
        // `supplementaryView(forElementKind:at:)` also returns prepared views UIKit is not displaying.
        guard indexPathsForVisibleSupplementaryElements(ofKind: elementKind).contains(indexPath) else { return nil }
        return supplementaryView(forElementKind: elementKind, at: indexPath)
    }

    /**
     Like `displayedSupplementaryViewOrThrow(ofKind:at:)`, but casts the live view to `T`.

     - throws:
     The failures of the untyped method, or a `FleetFailure` of kind `.invalidInput` when a displayed
     view is not of the requested type. A view that is not displayed returns `nil`.
     */
    public func displayedSupplementaryViewOrThrow<T>(ofKind elementKind: String, at indexPath: IndexPath, asType type: T.Type) throws -> T? where T: UICollectionReusableView {
        guard let view = try displayedSupplementaryViewOrThrow(ofKind: elementKind, at: indexPath) else { return nil }
        guard let castedView = view as? T else {
            throw FleetFailure(kind: .invalidInput, action: "inspect supplementary view",
                               target: "UICollectionView supplementary view `\(elementKind)` \(indexPath.item) in section \(indexPath.section)",
                               state: "the view is of type `\(Swift.type(of: view))`",
                               reason: "Supplementary view is of type `\(Swift.type(of: view))` (wanted `\(type)`).")
        }
        return castedView
    }
}
