## UIStoryboard

### Mocking view controllers on storyboards

Storyboards can significantly speed up development of your iOS app. Unit testing individual components is challenging, though, because controlling for the integration points of all those components (particularly connections through segues) is not readily done using UIKit's interface. Fleet helps you solve this problem in your tests by allowing your test code to mock out the elements bound to a storyboard's identifiers.

For example, suppose I have a storyboard with an initial view controller of type `ViewControllerA`. It has a button that triggers a segue to a view controller of type `ViewControllerB`. `ViewControllerB` does a bunch of stuff in its `viewDidLoad` method (e.g. network calls, creating subviews, etc.) that I don't care to allow under test. I still, however, want to test that the transitioning occurs when I fire the segue. The following code accomplishes this:

```swift
let storyboard = UIStoryboard(name: "MyStoryboard", bundle: nil)
let mockControllerB = try! storyboard.mockIdentifier("ViewControllerB", usingMockFor: ViewControllerB.self)

// Hold onto 'mockControllerB' and write the test code that would lead to ViewControllerB's presentation.
// Then test that it got presented however your test code normally accomplishes this.
```

In the above code `mockControllerB` will be returned by the storyboard anytime code executes that tries to grab the storyboard identifier "ViewControllerB". The mock returned is a full-fledged `ViewControllerB` object with all that class's properties, functions, and behavior EXCEPT for all its UIKit view controller lifecyle code. That is, when `mockControllerB` is presented in code, it runs empty implementations of `viewDidLoad`, `viewWillAppear(_:)`, `viewDidAppear(_:)`, `viewWillDisappear(_:)`, and `viewDidDisappear(_:)`.

This mocking allows true unit testing of an individual view controller within a storyboard. All that view controller's interactions with its sibling elements are untouched. Only the _behavior_ of those sibling elements are changed -- something that was already abstracted to our view controller under test anyway.

There are three functions on the mocking interface:

```swift
// Mocks the identifier of a local view controller on a storyboard
let _ = try turtlesAndFriendsStoryboard.mockIdentifier("SomeIdentifier", usingMockFor: SomeViewController.self)

// Mocks an identifier of a view controller originating from a local external storyboard reference on a storyboard
let _ = try storyboard.mockIdentifier("SomeOtherIdentifier", forReferencedStoryboardWithName: "SomeOtherStoryboard", usingMockFor: SomeOtherViewController.self)

// Mocks the initial view controller originating from a local external storyboard reference on a storyboard
let _ = try storyboard.mockInitialViewController(forReferencedStoryboardWithName: "SomeOtherStoryboard", usingMockFor: UIViewController.self)
```

### Binding to storyboard elements

Fleet allows you to bind specific instances to view controller references, and even storyboard references.

Suppose there is a storyboard called "TurtlesStoryboard", and it has a view controller on it with Storyboard Id "BoxTurtleViewController". You can use `bind(viewController:toIdentifier:)` to control the instance created by the storyboard. For example,

```swift
let mockBoxTurtleViewController = BoxTurtleViewController()
try! turtleStoryboard.bind(viewController: mockBoxTurtleViewController, toIdentifier: "BoxTurtleViewController")

let returnedBoxTurtleViewController = turtleStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")

// At this point, returnedBoxTurtleViewController will be the same instance as mockBoxTurtleViewController
```

#### Storyboard references

Fleet's binding supports storyboard references as well. Suppose TurtlesStoryboard has a reference to another storyboard, called "PuppiesStoryboard". And suppose that TurtlesStoryboard segues into a PuppiesStoryboard view controller with the Storyboard Id "CorgiViewController". We can bind a view controller instance to this storyboard reference by using `bind(viewController:toIdentifier:forReferencedStoryboardWithName:)`. For example,

```swift
let mockCorgiViewController = CorgiViewController()
try! turtleStoryboard.bind(viewController: mockCorgiViewController, toIdentifier: "CorgiViewController", forReferencedStoryboardWithName: "CorgiStoryboard")

let boxTurtleViewController = turtleStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")

// Do some code that expects to trigger a segue to present the CorgiViewController on the BoxTurtleViewController

expect(boxTurtleViewController.presentedViewController).to(beIdenticalTo(mockCrabViewController))
```

If you would like to bind to the initial view controller of a storyboard reference, use `bind(viewController:asInitialViewControllerForReferencedStoryboardWithName:)`.

### Error messaging

Notice that each call to a storyboard helper method above follows a `try!`. All storyboard helper methods throw descriptive errors that inform you of insufficient set-up of your storyboards. The intention is that the error messages make apparent the changes required in the production code to satisfy the test's expectations of the storyboard under test.
