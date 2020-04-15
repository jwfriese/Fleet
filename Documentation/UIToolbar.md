## UIToolbar

Unit testing the behavior of items on `UIToolbar`s through UIKit is ordinarily a challenge because of how
 difficult accessing the toolbar items directly can be.

Fleet aims to erase this pain by providing a way to "tap" on tooltip items in-test to fire their associated handlers.

Suppose you have a `UIToolbar` set up on a page in your storyboard. With Fleet, you can unit test the behavior of
 tapping that toolbar's items much more easily than before. With one simple line of code, an item's handler can be fired:
```swift
// Suppose we have items in a toolbar associated with `navigationController`
let toolbar = navigationController.toolbar!
toolbar.tapItem(withTitle: "Some Item")

// Now you can make any assertions you'd like on the behavior of tapping that item.
```
