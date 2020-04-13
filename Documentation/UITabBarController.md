## UITabBarController

Similar to user interactions with a [UITableView](UITableView.md), interactions with a `UITabBarController` _can_ be
mimicked programmatically for the sake of unit testing, it's just tedious, since the tester needs to remember to call
all the delegate methods that are called by the system in production.

With Fleet, the tester need only get a handle on the tab bar controller itself in their test code, and from there, they
will be able to switch tabs using the following code:
```swift
// Fetch the tab bar controller under test in whatever way makes sense.
var tabBarController: UITabBarController!
// then later...
tabBarController.selectTab(withLabelText: "Tab Text")

// Now you can make any assertions you'd like on the behavior that you like to see when the tab change occurs.
```

Another convenience method that behaves very similarly -- `UITabBarController.selectTab(withIndex:)` -- is also
provided.
