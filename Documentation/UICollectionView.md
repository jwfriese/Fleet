## UICollectionView

### Fetching cells
`fetchCell(at:)` and `fetchCell(at:asType:)` return the cell at an index path. UIKit only builds cells during layout,
so the collection view is laid out and, for off-screen items, scrolled (without animation) to the item first. A `FleetError` is raised if there is no data source, or the section or item
does not exist. `fetchCell(at:asType:)` also raises if the cell is not of the requested type.

```swift
let cell = collectionView.fetchCell(at: IndexPath(item: 1, section: 0), asType: PhotoCell.self)
```

`fetchCellOrThrow(at:)` and `fetchCellOrThrow(at:asType:)` do the same work but throw a `FleetFailure` instead of raising:
`.invalidSetup` without a data source, `.invalidInput` for a missing section or item (or a mistyped cell), and
`.unavailableInteraction` when UIKit cannot display the cell.

### Inspecting cells
Two differently named paths exist because they answer different questions:

| Method | Returns | Mutates the collection view? |
| --- | --- | --- |
| `displayedCell(at:)` / `displayedCell(at:asType:)` | The live cell UIKit is displaying, or `nil` if the item has no live cell (e.g. off screen) | No |
| `fetchCell(at:)` / `fetchCell(at:asType:)` | The live cell, after laying out and (if needed) scrolling to the item | Yes (layout, scroll position) |

Live cells are reused by UIKit, so do not hold one across a scroll or reload. Fleet deliberately has no "configured cell" helper that
calls `collectionView(_:cellForItemAt:)` or a diffable cell provider directly: those call `dequeueReusableCell`, which UIKit only supports during its own
cell request, and a cell dequeued outside one makes later layout raise `NSInternalInconsistencyException`. Use `fetchCell(at:)` to get a
data-source-configured cell for any item (it works with ordinary data sources and with stable `UICollectionViewDiffableDataSource` snapshots).
Index paths with fewer than two components, a missing data source, or a missing section/item raise a `FleetError`, and the typed variants raise a diagnostic naming
the found and requested types when the cell is of another type.

### Item selection
`UICollectionView.selectItem(at:animated:scrollPosition:)` changes the selection but does not call delegate methods.
Fleet's `selectItem(at:)` mimics a user tap:

- `collectionView(_:shouldSelectItemAt:)` is consulted; if it returns `false`, nothing changes
- When the collection view does not allow multiple selection, previously selected items are deselected (if `shouldDeselectItemAt` returns `false`, nothing changes), calling
`collectionView(_:shouldDeselectItemAt:)` and `collectionView(_:didDeselectItemAt:)`
- When it allows multiple selection, tapping an already-selected item deselects it (with the deselection callbacks)
- The item is selected and `collectionView(_:didSelectItemAt:)` is called

Selecting an already-selected item in single-selection mode runs `shouldSelectItemAt` and `didSelectItemAt` again. Callback order for a
selection that replaces another is `shouldSelect`, `shouldDeselect`, `didDeselect`, `didSelect`.

A `FleetError` is raised if the data source is missing, `allowsSelection` is `false`, or the index path (including negative values) does not exist. Validation happens before any state changes.

### Item deselection
`deselectItem(at:)` runs `collectionView(_:shouldDeselectItemAt:)` and, unless the delegate refuses (in which case the item stays
selected and nothing is raised), deselects the item and calls `collectionView(_:didDeselectItemAt:)`. It works in single- and multiple-selection modes,
and leaves other selected items alone. It raises a `FleetError` if the data source is missing, `allowsSelection` is `false`, the index path does not exist, or the item is not selected.

### Example
```swift
@MainActor
func testSelectingAPhoto() async {
    let collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), collectionViewLayout: UICollectionViewFlowLayout())
    collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "photo")
    let dataSource = UICollectionViewDiffableDataSource<Int, String>(collectionView: collectionView) { view, indexPath, name in
        let cell = view.dequeueReusableCell(withReuseIdentifier: "photo", for: indexPath) as! PhotoCell
        cell.name = name
        return cell
    }
    var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
    snapshot.appendSections([0])
    snapshot.appendItems(["Dune", "Fern"])
    await dataSource.apply(snapshot, animatingDifferences: false)

    let selected = IndexPath(item: 1, section: 0)
    XCTAssertEqual(collectionView.fetchCell(at: selected, asType: PhotoCell.self).name, "Fern")
    collectionView.selectItem(at: selected)
    XCTAssertEqual(collectionView.indexPathsForSelectedItems, [selected])
    collectionView.deselectItem(at: selected)
}
```

(The same flow, with a plain `UICollectionViewCell`, is compiled by the external consumer test `testCollectionViewSelectionAndCellInspectionWithDiffableDataSource`.)

### Limits of programmatic interaction
These helpers dispatch what the data source and delegate would receive from a tap; they do not prove hit testing, gesture recognition,
accessibility, focus movement (tvOS), or highlight callbacks (`shouldHighlightItemAt`, `didHighlightItemAt`). The callback sequences are
Fleet's documented model, verified by the hosted specs. `UICollectionView_UIKitReferenceSpec` records what UIKit itself does for the public programmatic
APIs (no delegate callbacks, single-selection replacement, `allowsSelection = false`); real touch traces need private APIs and are not recorded. A probe of the only public activation route, `UICollectionViewCell.accessibilityActivate()`, returned `false` in a hosted test and fired no delegate callbacks or selection, so it cannot serve as a UIKit-driven reference. Supplementary views, in-flight or animated snapshot
updates (apply snapshots with `animatingDifferences: false` and await completion first), complex multiple-selection gestures, and `UICollectionViewController` mocking
(see issue #23) are not covered.

This is programmatic dispatch: it does not prove hit testing, and it does not call the highlight callbacks.

### Recoverable failures
`selectItemOrThrow(at:)` performs the same interaction as `selectItem(at:)` but reports problems as a typed Swift
`FleetFailure` instead of raising an `NSException`, so the test process survives and the failure can be asserted:

```swift
XCTAssertThrowsError(try collectionView.selectItemOrThrow(at: IndexPath(item: 9, section: 0))) { error in
    XCTAssertEqual((error as? FleetFailure)?.kind, .invalidInput)
}

// Swift Testing
#expect(throws: FleetFailure.self) { try collectionView.selectItemOrThrow(at: IndexPath(item: 9, section: 0)) }
```

A `FleetFailure` carries its `kind`, the attempted `action`, the `target` control and index, the relevant `state`, and a `reason`.
A delegate returning `false` from `shouldSelectItemAt`/`shouldDeselectItemAt` is not an error: the call returns
`.refusedByDelegate(method:)`, otherwise `.performed`. See [the FAQ](FAQ.md#how-do-i-migrate-from-fleeterror-and-swallowanyerrors) for migration.
