## UIButton

Rather than using:

```swift
let someButton = viewControllerWithButton.buttonUnderTest
someButton.sendActionForControlEvents(.TouchUpInside)
```

you can use Fleet's extension `tap` like so:

```swift
let someButton = viewControllerWithButton.buttonUnderTest
someButton.tap()
```

