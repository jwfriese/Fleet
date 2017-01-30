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

## Why does Fleet throw errors for almost all its interactions with UIKit?
The Fleet team has two general goals in mind as the framework develops:

1) To enable simpler, more thorough testing of production code interactions with UIKit.

2) To provide better signalling when something goes wrong.

Most of Fleet's API throws, and #2 is the reason. Fleet throws when something is wrong and needs to be
addressed. Swift's error mechanisms are nice to work with, and so you and your team have options for
how to handle Fleet's throw-heavy API:

1) `try!` calls to the Fleet API

This is the recommended method of working with Fleet in your test code. During the normal course of
development, if you work one test at a time, or even just one flow at a time, you'll want quick, clear
feedback when something goes wrong.

2) `try?` calls to the Fleet API

If you decide that you'd rather not halt everything when Fleet sees an error in setup or expectation,
ignoring the errors will allow control to fall through to the rest of your test code. Your other
assertions should catch any misbehavior resulting from the bad state that Fleet would have alerted you
to through the ignored error.

3) Catch any errors thrown by the Fleet API

Fleet documents the types of errors thrown by all of its API methods, allowing you to easily wrap calls
in a `do-catch` block. For example:

```swift
do {
	try myTextField.enter("some text")
} catch let error: Fleet.TextFieldError {
	// Do any recovery here
}
```

## Why should I make sure all `UIViewController` tests happen in a `UIWindow`?
Fleet recommends that all view controller tests happen specifically in the `UIWindow` object that is
the key window of your test host's app delegate. Whether you create your own for test or use the
production app delegate, it should host the view controller under test.

The primary reason for this is that plenty of UIKit functionality expects that the UI elements it
operates with live in a view hierarchy. An example of this can be found within the test code for Fleet
itself: the unit tests for `UITextField` embed the text field under test in the view hierarchy in the setup
code. This is because the text field's attempts to call `becomeFirstResponder()` always fail if the text
field is not in the view hierarchy. Views can only participate in the responder chain if they live in a
view hierarchy.

Another example of this is presenting a controller on top of another controller. If the presenting view
controller's view does not live in the window hierarchy, UIKit prints a message that looks something like the
following:

```
Attempt to present UIAlertController: 0x727a2b40 on TurtleViewController: 0x897ac100 whose view is not in the window hierarchy!
```

If the production code does this, the view controller never shows up on the screen. Fundamentally, it is misbehavior, and exposes
the test code to subtle errors that could prove tough to track down. It's at best _possible_ that it has no behavioral effect, and
test run to test run you can never know for sure. Tests exist to increase confidence in the behavior of production code -- a
little detail like this should not compromise that.

Fleet makes it easy to ensure your view controllers are in the key window hierarchy:
```swift
// Takes a `UIViewController`,  makes it the test app key window's root, and kicks off its lifecycle.
Fleet.setAsAppRootWindow(_:)

// Takes a `UIViewController`,  makes it the root of a navigation stack, kicks off the lifecycle, and
// returns the navigation controller that hosts that view controller.
Fleet.setInAppWindowRootNavigation(_:)
```
