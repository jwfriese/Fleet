# FAQ
## Does Fleet do lots of swizzling to provide its features?
The short answer is yes, Fleet swizzles.

That said, the Fleet team puts a lot of effort into ensuring that swizzling to _change UIKit behavior_
is kept to a minimum. Most swizzling within Fleet is there to add behavior into a UIKit flow.

Here is an exhaustive list of behavior-altering swizzles used by Fleet:
- Swizzling `UIViewController` and `UINavigationController` presentation methods to turn off animations

This swizzling is done to make the processing of transitions between view controllers more
consistent between tests. Fleet explicitly stops short of forcing transitions to happen
immediately with swizzling -- your tests will still have to let the UI thread finish processing.

## I could accomplish the same thing by calling all the delegate methods and events myself, right?
Yes, you could, and many projects and teams probably do this already. In fact, Fleet's very first feature was a
quick little helper that wrapped the following line of code:

```swift
button.sendActions(for: .touchUpInside)
```

(Of course, even this iteration failed to call _all_ the correct control events.)

For a button, it might be easy to remember to send the relevant control events. What about something more
complex, like selecting a table view row? Here are all the things Fleet's `UITableView.selectRow(at:)`
extension method does:
```
- `UITableViewDelegate.tableView(_:willSelectRowAt:)` is called at the appropriate time
- `UITableViewDelegate.tableView(_:didSelectRowAt:)` is called at the appropriate time
- `UITableViewDelegate.tableView(_:willDeselectRowAt:)` is called at the appropriate time, and only when
a deselection would occur
- `UITableViewDelegate.tableView(_:didDeselectRowAt:)` is called at the appropriate time, and only when
a deselection would occur
- All the appropriate `NSNotification`s are posted
- The cell is actually selected
- Any previously selected cell is deselected
```

A lot of table view code out there probably does not care too much about most of the list above. For
the code that does, however, you and your team can rest easy knowing that whether your table view row
selection code's production implementation is simple with a single delegate hook-in, or complex with
fully-implemented delegate callbacks and notification handlers, the test code to set it all in motion looks
exactly the same:

```swift
try! myTableView.selectRow(at: myIndexPath)
```

The principles laid out above for just one of Fleet's `UITableView` extensions apply to all of the
framework's UIKit extensions.
