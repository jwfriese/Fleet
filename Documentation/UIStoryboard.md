## UIStoryboard

### Binding to storyboard elements

Fleet allows you to bind specific instances to view controller references, and even storyboard references.

Suppose there is a storyboard called "TurtlesStoryboard", and it has a view controller on it with Storyboard Id "BoxTurtleViewController". You can use `bindViewController(_:toIdentifier:)` to control the instance created by the storyboard. For example,

```swift
let mockBoxTurtleViewController = BoxTurtleViewController()
try! turtleStoryboard.bindViewController(mockBoxTurtleViewController, toIdentifier: "BoxTurtleViewController")
        
let returnedBoxTurtleViewController = turtleStoryboard.instantiateViewControllerWithIdentifier("BoxTurtleViewController")

// At this point, returnedBoxTurtleViewController will be the same instance as mockBoxTurtleViewController
```

#### Storyboard references

Fleet's binding supports storyboard references as well. Suppose TurtlesStoryboard has a reference to another storyboard, called "PuppiesStoryboard". And suppose that TurtlesStoryboard segues into a PuppiesStoryboard view controller with the Storyboard Id "CorgiViewController". We can bind a view controller instance to this storyboard reference by using `bindViewController(_:toIdentifier:forReferencedStoryboardWithName:)`. For example,

```swift
let mockCorgiViewController = CorgiViewController()
try! turtleStoryboard.bindViewController(mockCorgiViewController, toIdentifier: "CorgiViewController", forReferencedStoryboardWithName: "CorgiStoryboard")
        
let boxTurtleViewController = turtleStoryboard.instantiateViewControllerWithIdentifier("BoxTurtleViewController")

// Do some code that expects to trigger a segue to present the CorgiViewController on the BoxTurtleViewController
        
expect(boxTurtleViewController.presentedViewController).to(beIdenticalTo(mockCrabViewController))
```

If you would like to bind to the initial view controller of a storyboard reference, use `bindViewController(_:asInitialViewControllerForReferencedStoryboardWithName:)`.

