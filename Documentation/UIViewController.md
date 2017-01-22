## UIViewController

When firing code in test that would make a view controller either present or dismiss, Fleet forces the results of the action to occur immediately. Your test code won't have to wait for the run-loop to assert your expectations.

```swift
let bottom = UIViewController()
let top = UIViewController()

bottom.present(top, animated: true, completion: nil)

// You can test that the present has successfully occurred immediately after executing it.
expect(bottom.presentedViewController).to(beIdenticalTo(top))
expect(top.presentingViewController).to(beIdenticalTo(bottom))

bottom.dismiss(animated: true, completion: nil)

// Likewise with the dismiss -- as soon as you call the code, you can assert on the results.
expect(bottom.presentedViewController).to(beNil())
expect(top.presentingViewController).to(beNil())
```

Even the completion handlers passed in will fire immediately:
```swift
let bottom = UIViewController()
let top = UIViewController()

var didFireCompletionHandler = false
let completionHandler = {
    didFireCompletionHandler = true
}

bottom.present(top, animated: true, completion: completionHandler)

// The results of the completion handler can be seen immediately.
expect(didFireCompletionHandler).to(beTrue())
```

