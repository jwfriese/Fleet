## UICollectionView

### Fetching cells
`fetchCell(at:)` and `fetchCell(at:asType:)` return the cell at an index path. UIKit only builds cells during layout,
so the collection view is laid out and, for off-screen items, scrolled (without animation) to the item first. A `FleetError` is raised if there is no data source, or the section or item
does not exist. `fetchCell(at:asType:)` also raises if the cell is not of the requested type.

```swift
let cell = collectionView.fetchCell(at: IndexPath(item: 1, section: 0), asType: PhotoCell.self)
```

### Item selection
`UICollectionView.selectItem(at:animated:scrollPosition:)` changes the selection but does not call delegate methods.
Fleet's `selectItem(at:)` mimics a user tap:

- `collectionView(_:shouldSelectItemAt:)` is consulted; if it returns `false`, nothing changes
- When the collection view does not allow multiple selection, previously selected items are deselected (if `shouldDeselectItemAt` returns `false`, nothing changes), calling
`collectionView(_:shouldDeselectItemAt:)` and `collectionView(_:didDeselectItemAt:)`
- When it allows multiple selection, tapping an already-selected item deselects it (with the deselection callbacks)
- The item is selected and `collectionView(_:didSelectItemAt:)` is called

A `FleetError` is raised if the data source is missing, `allowsSelection` is `false`, or the index path does not exist.

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
