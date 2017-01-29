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

All this setup, and the code _still_ isn't even testing deselection behavior.

Fleet provides a helper method that lets developers write test setup code like this for _all_
table view behavior tests:
```swift
try! tableView.selectRow(at: indexPath)
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

Additionally, the method throws an error clearly that describes any problem that occurs
when attempting to take the selection action, such as:
- Attempting to select an index path that does not exist in the table
- Attempting to select an index path that does not allow selection

### Fetching a cell
Fetching a cell in test requires a surprising amount of work:
```swift
// Get it and make sure it is not nil
var cell = subject.tableView(subject.teamPipelinesTableView!, cellForRowAt: IndexPath(row: 0, section: 0))
expect(cellOne).toNot(beNil())

// Optionally cast it to the kind of cell you want
// cell = cell as? KindOfCellIWant

// Now you can start doing assertions
```

The above code could condense into one line. Even then, error messaging from UIKit does not make it obvious
why a fetch failed. Fleet provides an extension to help address these difficulties:
```swift
try! let cell = subject.tableView.fetchCell(at: IndexPath(row: 0, section: 0)
// Now you can start doing assertions -- the cell that comes back is not an optional.
```

The test code can also cast as part of the call:
```swift
try! let cell = subject.tableView.fetchCell(at: IndexPath(row: 0, section: 0, asType: KindOfCellIWant.self)
// Now you can start doing assertions -- `cell` above is of type `KindOfCellIWant`
```

Functionally, this is the same as appending your own `as! KindOfCellIWant` at the end of the call to `fetchCell(at:)`,
except Fleet's version tries to give a more descriptive error message.

These methods throw errors that attempt to describe specifically why the fetch failed.

### Selecting a custom table view cell edit action
Fleet also provides a helper method for selecting custom edit actions on a row:
```swift
try! tableView.selectCellAction(withTitle: "Edit Action Title", at: indexPath)
```

When this method is called, all the following occurs:
- `UITableViewDelegate.tableView(_:willBeginEditingRowAt:)` is called at the appropriate time
- `UITableViewDelegate.tableView(_:willEndEditingRowAt:)` is called at the appropriate time
- The callback assigned to that edit action is called

The method throws an error that clearly describes any problem that occurs
when attempting to take the edit action, such as:
- Attempting to take an edit action on an index path that does not exist in the table
- Attempting to take an edit action on an index path that does not allow editing
- Attempting to take an edit action that does not exist at that index path
