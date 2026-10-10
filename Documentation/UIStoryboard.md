# UIStoryboard

Platforms: iOS, tvOS

Storyboard helpers replace the view controllers a storyboard returns, so one controller can be tested apart from its siblings. Call them before the storyboard instantiates the identifier.

All methods are `throws`. Use `try`. Errors are `Fleet.StoryboardError` values that describe what is missing from the storyboard.

## Methods

| Method | Summary |
| --- | --- |
| [`mockIdentifier(_:usingMockFor:)`](#mockidentifierusingmockfor) | Mocks a local view controller. |
| [`mockIdentifier(_:forReferencedStoryboardWithName:usingMockFor:)`](#mockidentifierforreferencedstoryboardwithnameusingmockfor) | Mocks a view controller in a referenced storyboard. |
| [`mockInitialViewController(forReferencedStoryboardWithName:usingMockFor:)`](#mockinitialviewcontrollerforreferencedstoryboardwithnameusingmockfor) | Mocks the initial controller of a referenced storyboard. |
| [`bind(viewController:toIdentifier:)`](#bindviewcontrollertoidentifier) | Returns a given instance for a local identifier. |
| [`bind(viewController:toIdentifier:forReferencedStoryboardWithName:)`](#bindviewcontrollertoidentifierforreferencedstoryboardwithname) | Returns a given instance for an identifier in a referenced storyboard. |
| [`bind(viewController:asInitialViewControllerForReferencedStoryboardWithName:)`](#bindviewcontrollerasinitialviewcontrollerforreferencedstoryboardwithname) | Returns a given instance as a referenced storyboard's initial controller. |

## Mocking

A mock is a full instance of the class with empty `viewDidLoad`, `viewWillAppear(_:)`, `viewDidAppear(_:)`, `viewWillDisappear(_:)`, and `viewDidDisappear(_:)`. Its other properties and methods are untouched.

### `mockIdentifier(_:usingMockFor:)`

```swift
func mockIdentifier<T>(_ identifier: String, usingMockFor classToMock: T.Type) throws -> T where T: UIViewController
```

Returns a mock the storyboard supplies for `identifier`.

### `mockIdentifier(_:forReferencedStoryboardWithName:usingMockFor:)`

```swift
func mockIdentifier<T>(_ identifier: String, forReferencedStoryboardWithName referencedStoryboardName: String, usingMockFor classToMock: T.Type) throws -> T where T: UIViewController
```

Same, for an identifier reached through an external storyboard reference.

### `mockInitialViewController(forReferencedStoryboardWithName:usingMockFor:)`

```swift
func mockInitialViewController<T>(forReferencedStoryboardWithName name: String, usingMockFor classToMock: T.Type) throws -> T where T: UIViewController
```

Same, for the initial view controller of a referenced storyboard.

## Binding

Binding supplies your own instance rather than a mock. It works for any controller reference, including embedded ones.

### `bind(viewController:toIdentifier:)`

```swift
func bind(viewController: UIViewController, toIdentifier identifier: String) throws
```

### `bind(viewController:toIdentifier:forReferencedStoryboardWithName:)`

```swift
func bind(viewController: UIViewController, toIdentifier identifier: String, forReferencedStoryboardWithName referencedStoryboardName: String) throws
```

### `bind(viewController:asInitialViewControllerForReferencedStoryboardWithName:)`

```swift
func bind(viewController: UIViewController, asInitialViewControllerForReferencedStoryboardWithName referencedStoryboardName: String) throws
```

## Examples

Mock a destination reached by segue:

```swift
let storyboard = UIStoryboard(name: "MyStoryboard", bundle: nil)
let mockB = try storyboard.mockIdentifier("ViewControllerB", usingMockFor: ViewControllerB.self)
// Trigger the segue, then assert mockB was presented.
```

Bind an instance:

```swift
let boxTurtle = BoxTurtleViewController()
try turtleStoryboard.bind(viewController: boxTurtle, toIdentifier: "BoxTurtleViewController")

let result = turtleStoryboard.instantiateViewController(withIdentifier: "BoxTurtleViewController")
// result === boxTurtle
```

Bind into a referenced storyboard:

```swift
let corgi = CorgiViewController()
try turtleStoryboard.bind(viewController: corgi, toIdentifier: "CorgiViewController", forReferencedStoryboardWithName: "CorgiStoryboard")
```
