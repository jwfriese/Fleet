# UITableView

Platforms: `fetchCell` and `selectRow`: iOS, tvOS. `selectCellAction`: iOS only.

All methods raise a `Fleet.TableViewError` (`FleetError`) on failure.

## Methods

| Method | Summary |
| --- | --- |
| [`selectRow(at:)`](#selectrowat) | Selects a row as a user would, with delegate callbacks and notifications. |
| [`fetchCell(at:)`](#fetchcellat) | Returns the cell from the data source. |
| [`fetchCell(at:asType:)`](#fetchcellatastype) | Returns the cell cast to a `UITableViewCell` subclass. |
| [`selectCellAction(withTitle:at:)`](#selectcellactionwithtitleat) | Runs a custom edit action on a row. |

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

### `selectCellAction(withTitle:at:)`

```swift
func selectCellAction(withTitle title: String, at indexPath: IndexPath)
```

Runs the custom edit action whose title equals `title`. Calls `tableView(_:willBeginEditingRowAt:)` and `tableView(_:didEndEditingRowAt:)`, and the action's handler.

**Raises** if the row does not exist, does not allow editing, or has no action with that title.

## Example

```swift
tableView.selectRow(at: IndexPath(row: 1, section: 0))

let cell = tableView.fetchCell(at: IndexPath(row: 0, section: 0), asType: MyCell.self)
expect(cell.titleLabel.text).to(equal("First"))

tableView.selectCellAction(withTitle: "Delete", at: IndexPath(row: 0, section: 0))
```

## Notes

- Methods raise Objective-C exceptions, not Swift errors. Do not use `try`. See the [FAQ](FAQ.md#why-does-fleet-raise-exceptions-and-how-should-i-handle-them).
