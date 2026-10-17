# UITableView

Platforms: `fetchCell` and `selectRow`: iOS, tvOS. `performContextualAction`: iOS only.

The classic methods raise a `Fleet.TableViewError` (`FleetError`) on failure. `selectRowOrThrow(at:)`, `fetchCellOrThrow`, and
`fetchDisplayedCellOrThrow` perform the same work but throw a typed `FleetFailure` (see [UICollectionView](UICollectionView.md#recoverable-failures)),
so the failure can be asserted with `XCTAssertThrowsError` / `#expect(throws:)`. `selectRowOrThrow` returns `.refusedByDelegate`
when `willSelectRowAt` (or `willDeselectRowAt` in a multiple-selection toggle) returns `nil`; the classic form returns silently.
`performContextualActionOrThrow(withTitle:edge:at:completionTimeout:)` and `performContextualActionOrThrow(atIndex:edge:at:completionTimeout:)`
(each with an `async` form) throw `.invalidSetup`, `.invalidInput`, `.unavailableInteraction`, or `.timedOut` failures; the async forms
propagate task cancellation as `CancellationError`.

## Methods

| Method | Summary |
| --- | --- |
| [`selectRow(at:)`](#selectrowat) | Selects a row as a user would, with delegate callbacks and notifications. |
| [`fetchCell(at:)`](#fetchcellat) | Returns the cell from the data source. |
| [`fetchCell(at:asType:)`](#fetchcellatastype) | Returns the cell cast to a `UITableViewCell` subclass. |
| [`performContextualAction(withTitle:edge:at:completionTimeout:)`](#performcontextualaction) | Runs a leading or trailing swipe action by title (iOS only). |
| [`performContextualAction(atIndex:edge:at:completionTimeout:)`](#performcontextualaction) | Runs a leading or trailing swipe action by index (iOS only). |

### `selectRow(at:)`

```swift
func selectRow(at indexPath: IndexPath)
```

Mimics a user selecting the row. In order of use:

- `tableView(_:willSelectRowAt:)` and `tableView(_:didSelectRowAt:)` are called.
- `tableView(_:willDeselectRowAt:)` and `tableView(_:didDeselectRowAt:)` are called only when a deselection would occur.
- Selection notifications are posted.
- The row is selected and any previously selected row is deselected.

`selectRow(at:animated:scrollPosition:)` does none of the delegate or notification work.

**Raises** if the table view has no data source, the row does not exist, or the table view does not allow selection.

### `fetchCell(at:)`

```swift
func fetchCell(at indexPath: IndexPath) -> UITableViewCell
```

Returns the cell the data source provides for `indexPath`.

**Raises** if the table view has no data source, or the section or row does not exist.

### `fetchCell(at:asType:)`

```swift
func fetchCell<T>(at indexPath: IndexPath, asType type: T.Type) -> T where T: UITableViewCell
```

Like `fetchCell(at:)`, cast to `T`. Unlike `as!`, a failed cast describes the found and requested types.

**Raises** in the cases above, or if the cell is not a `T`.

### `performContextualAction`

iOS only.

#### Selection contract
`selectRow(at:)` follows this order in single-selection mode: `willSelectRowAt`, `willDeselectRowAt` (previous row),
`didDeselectRowAt`, `didSelectRowAt`. Delegate methods that are not implemented are skipped.
- If `willSelectRowAt` returns `nil`, nothing changes (no deselection, no selection, no notification).
- A redirected index path (from `willSelectRowAt` or `willDeselectRowAt`) is validated before any selection change or `did...` callback; a nonexistent one raises/throws and changes nothing.
- If `willDeselectRowAt` returns `nil`, no deselect callback or notification is sent for that row.
- `UITableView.selectionDidChangeNotification` is posted with the table view as its object after each selection or deselection.
- Tapping the already selected row in single-selection mode reports select callbacks again and leaves it selected.
- With `allowsMultipleSelection` (or `allowsMultipleSelectionDuringEditing` while editing), other rows stay selected and
tapping a selected row deselects it.
- While `isEditing`, `allowsSelectionDuringEditing` governs selection instead of `allowsSelection`.

Not simulated: hit testing, highlighting (`shouldHighlightRowAt`), scrolling, and cell editing controls. Callback order
is derived from UIKit's documented behavior and verified by Fleet's own tests, not by physical touches.

### Fetching a cell
`fetchCell(at:)` returns a *configured* cell: it asks the data source for one (`tableView(_:cellForRowAt:)`), so it is not
necessarily the instance the table view displays. Use `fetchDisplayedCell(at:)` / `fetchDisplayedCell(at:asType:)` to get
the displayed instance (`cellForRow(at:)`). It raises if the row is not among `indexPathsForVisibleRows` (offscreen, retained-but-offscreen prepared cells, or not yet laid out) (call `layoutIfNeeded()` first).

```swift
@discardableResult
func performContextualAction(withTitle title: String, edge: SwipeActionEdge, at indexPath: IndexPath, completionTimeout: TimeInterval = 2) -> Bool
@discardableResult
func performContextualAction(atIndex index: Int, edge: SwipeActionEdge, at indexPath: IndexPath, completionTimeout: TimeInterval = 2) -> Bool
```

Fleet invokes `UIContextualAction`s that your table view delegate vends from
`tableView(_:leadingSwipeActionsConfigurationForRowAt:)` and
`tableView(_:trailingSwipeActionsConfigurationForRowAt:)`:
```swift
let performed = tableView.performContextualAction(withTitle: "Archive", edge: .trailing, at: indexPath)
tableView.performContextualAction(atIndex: 0, edge: .leading, at: indexPath)
```

Fleet asks the delegate for the configuration and calls the action's public `handler` exactly once,
passing the row's cell (displayed, or built by the data source if offscreen) as the source view. No
private API or runtime hook is involved, so any `UIContextualAction` the delegate returns works; there is no
Fleet-specific construction or registration.

What this establishes: the delegate vends that action for that row and edge, the data source allows editing
the row, and the handler runs and calls its completion closure. It does not prove the action is reachable by a
physical swipe, hit testing, or accessibility, and it does not render swipe buttons or perform the action's
default full-swipe behavior. `tableView(_:willBeginEditingRowAt:)` is called before the handler and
`tableView(_:didEndEditingRowAt:)` after completion.

- The return value is the `Bool` the handler passed to its completion closure (`false` means the action
  reports that it did nothing, like a refused action in UIKit).
- Handlers may complete asynchronously. Fleet runs the run loop until completion or `completionTimeout`
  (default 2 seconds). A handler that never completes raises an error after the timeout; a second
  completion call is ignored. `didEndEditingRowAt` is not called after a timeout.
- Selecting by title requires exactly one match on that edge. Zero matches, or duplicate titles (reported
  with the match count) raise an error; use `atIndex:` to choose between duplicates or untitled actions.
- Errors are raised for: missing data source or delegate, a delegate that does not implement the edge's method,
  a nonexistent section or row, a data source whose `tableView(_:canEditRowAt:)` returns `false`, a
  `nil`/empty configuration, an out-of-range index, and a handler that does not complete in time. A data source
  that does not implement `canEditRowAt` is treated as allowing edits, as UIKit does.

## Example

```swift
tableView.selectRow(at: IndexPath(row: 1, section: 0))

let cell = tableView.fetchCell(at: IndexPath(row: 0, section: 0), asType: MyCell.self)
expect(cell.titleLabel.text).to(equal("First"))

tableView.performContextualAction(withTitle: "Delete", edge: .trailing, at: IndexPath(row: 0, section: 0))
```

## Notes

- Methods raise Objective-C exceptions, not Swift errors. Do not use `try`. See the [FAQ](FAQ.md#why-does-fleet-raise-exceptions-and-how-should-i-handle-them).

## Migrating from `selectCellAction`
`selectCellAction(withTitle:at:)` and the `UITableViewRowAction.handler` interception were removed in the
next major version because `UITableViewRowAction` is deprecated and the interception depended on a private
initializer. Historical 4.x tags still contain them. Replace `tableView(_:editActionsForRowAt:)` with swipe
configurations:
```swift
// Before (4.x)
func tableView(_ tv: UITableView, editActionsForRowAt ip: IndexPath) -> [UITableViewRowAction]? {
    [UITableViewRowAction(style: .normal, title: "Archive") { _, ip in archive(ip) }]
}
tableView.selectCellAction(withTitle: "Archive", at: indexPath)

// After
func tableView(_ tv: UITableView, trailingSwipeActionsConfigurationForRowAt ip: IndexPath) -> UISwipeActionsConfiguration? {
    let archiveAction = UIContextualAction(style: .normal, title: "Archive") { _, _, completion in
        archive(ip)
        completion(true)
    }
    return UISwipeActionsConfiguration(actions: [archiveAction])
}
tableView.performContextualAction(withTitle: "Archive", edge: .trailing, at: indexPath)
```
From an `async` test, call the `async` overloads (`try`-free, `await`ed): they suspend the calling task, so a
handler that completes from `Task { @MainActor in ... }` works. The synchronous forms run the run loop and
cannot let such tasks run while the caller occupies the main actor.

Legacy row actions were always trailing; leading actions are new. Unlike the old helper, the handler must call its
completion closure.
