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

### Binding lifetime

Bindings and mocks belong to the `UIStoryboard` instance they were made on. They are released when that storyboard is deallocated, and a second storyboard with the same name never sees them. `XCTestCase` instances live until the whole run finishes, so a storyboard stored in a test property keeps its bound controllers alive; release them explicitly:

```swift
override func tearDown() async throws {
    storyboard.removeBindings()
    try await super.tearDown()
}

// Or scope them to a block (an async overload also cleans up on throw and cancellation):
try storyboard.withBindings {
    try storyboard.bind(viewController: controller, toIdentifier: "BoxTurtleViewController")
    // ...
}
```

`removeBindings()` affects only the storyboard it is called on. An Objective-C exception raised by a failing `bind` unwinds through Swift frames without releasing the references they held, so a controller passed to a rejected call may stay alive; construct controllers for failing calls inside an `autoreleasepool` only if that matters to your test, and do not rely on their release.

### Choosing metadata explicitly

Fleet validates identifiers against compiled storyboard metadata copied into the test bundle by the metadata script. By default it infers the storyboard's name and searches every loaded `.xctest` bundle: one match is used, identical copies in several bundles are accepted, and differing copies fail with an error naming each file. To avoid inference, or to read metadata from another bundle, name it before the first binding:

```swift
let storyboard = UIStoryboard(name: "Turtles", bundle: nil)
try storyboard.useBindingMetadata(forStoryboardNamed: "Turtles", in: Bundle(for: MyTests.self))
```

A bundle without `StoryboardInfo/<name>/Info.plist`, or with an unreadable one, fails with a message naming the bundle or file.

### Lifecycle suppression limits

A mock suppresses `viewDidLoad`, `viewWillAppear(_:)`, `viewDidAppear(_:)`, `viewWillDisappear(_:)`, and `viewDidDisappear(_:)`. It does not stop initializers (`init(coder:)`, `init(nibName:bundle:)`, or designated initializers) from running, nor property initializers or `prepare(for:sender:)` on a source controller, so any side effects there still happen. `UICollectionViewController` subclasses cannot be mocked (see issue #23); mock a `UIViewController` subclass, or bind a real instance instead.
