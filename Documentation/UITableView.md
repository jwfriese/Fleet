## UITableView

### Row selection
A table view's many delegate and data source methods contribute to the complexity of
testing their behavior reliably, consistently, and succinctly. For example, when trying
to test how the app behaves when a particular cell on a table view is selected, a
developer might write code like the following:

```swift
// Set up table view
// ...
// This does it, right?
subject.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)

// Go test that the thing happened
```

While this successfully selects the row, it does not fire delegate callbacks. It also
does not post table selection notifications. To get all these behaviors, the test code
will have to look like this:

```swift
// Set up table view
// ...
subject.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
subject.tableView(subject.someTableView!, willSelectRowAt: IndexPath(row: 1, section: 0))
subject.tableView(subject.someTableView!, didSelectRowAt: IndexPath(row: 1, section: 0))
NotificationCenter.default.post(name: NSNotification.Name.UITableViewSelectionDidChange, object: nil)

// Go test that the thing happened
```

All this setup, and the code still isn't even testing deselection behavior. Fleet provides a helper method
that lets developers write test setup code like this for _all_ table view behavior tests:
```swift
let _ = tableView.selectRow(at: indexPath)
```

When this method is called, all the following occurs:
- `UITableViewDelegate.tableView(_:willSelectRowAt:)` is called at the appropriate time
- `UITableViewDelegate.tableView(_:didSelectRowAt:)` is called at the appropriate time
- `UITableViewDelegate.tableView(_:willDeselectRowAt:)` is called at the appropriate time, and only when
a deselection would occur
- `UITableViewDelegate.tableView(_:didDeselectRowAt:)` is called at the appropriate time, and only when
a deselection would occur
- All the appropriate `NSNotification`s are posted
- The cell is actually selected
- Any previously selected cell is deselected

In other words, Fleet does its best to make the test code setup act as closely to production code
as possible, so that the developer can feel confident that their tests are telling them the truth
about their code.

Additionally, the method returns an error object that clearly describes any problem that occurs
when attempting to take the selection action, such as:
- Attempting to select an index path that does not exist in the table
- Attempting to select an index path that does not allow selection

### Selecting a custom table view cell edit action
Fleet also provides a helper method for selecting custom edit actions on a row:
```swift
let _ = tableView.selectCellAction(withTitle: "Edit Action Title", at: indexPath)
```

When this method is called, all the following occurs:
- `UITableViewDelegate.tableView(_:willBeginEditingRowAt:)` is called at the appropriate time
- `UITableViewDelegate.tableView(_:willEndEditingRowAt:)` is called at the appropriate time
- The callback assigned to that edit action is called

The method returns an error object that clearly describes any problem that occurs
when attempting to take the edit action, such as:
- Attempting to take an edit action on an index path that does not exist in the table
- Attempting to take an edit action on an index path that does not allow editing
- Attempting to take an edit action that does not exist at that index path
