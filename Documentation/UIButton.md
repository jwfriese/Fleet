## UIButton

Rather than using:

```swift
let someButton = viewControllerWithButton.buttonUnderTest
someButton.sendActions(for: .touchUpInside)
```

you can use Fleet's extension `tap` like so:

```swift
let someButton = viewControllerWithButton.buttonUnderTest
someButton.tap()
```

