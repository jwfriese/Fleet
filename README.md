# Fleet [![Build Status](https://travis-ci.org/jwfriese/Fleet.svg?branch=master)](https://travis-ci.org/jwfriese/Fleet)
Fleet is a UIKit-focused testing framework intended for use on iOS projects written in Swift.

## Installation

See the [Installation section](./Documentation/Installation.md) for details about installing Fleet in your project.

## Features

### Storyboard injection and mocking
Fleet allows test code to inject into and pull mocks from storyboards. This gives you the best of both worlds -- ability to test
your view controllers and their interactions with each other exactly as they are in production code without compromising the ability
to isolate any particular view controller for unit testing purposes.

Read more about using Fleet's storyboard features in the [Documentation section](./Documentation/UIStoryboard.md).

### Interaction with UIKit elements
Fleet extends UIKit classes in order to make it easier to test your code's interactions with UIKit. Following are summaries of the major features for each extended class. The [Documentation folder](./Documentation) contains more information about these features, as well as sample code showing you how they are intended to be used.

- [UIViewController](./Documentation/UIViewController.md) - Makes the UI run-loop behave more consistently to allow specs to test view controller presentation and dismissal with less effort.
- [UITableView](./Documentation/UITableView.md) - Provides methods mimicing user actions on table views, ensuring all appropriate delegate and data source callbacks are run.
- [UINavigationController](./Documentation/UINavigationController.md) - Allows specs to test pushing and popping on the navigation stack without waiting for the UI run-loop.
- [UIButton](./Documentation/UIButton.md) - Provides convenience methods for interacting with buttons in test.
- [UIBarButtonItem](./Documentation/UIBarButtonItem.md) - Provides convenience methods similar to those provided for UIButton.
- [UIAlertController](./Documentation/UIAlertController.md) - Allows specs to simply tap on alert actions in order to test their behavior.
- [UITextField](./Documentation/UITextField.md) - Provides convenience methods for entering text.
- [UISwitch](./Documentation/UISwitch.md) - Provides convenience methods for interacting with switches in test.
- [UITextView](./Documentation/UITextView.md) - Provides convenience methods for entering text into a text view.

### Setup for view controller tests
Fleet provides another method of help in setting up view controller alongside storyboard injection and mocking. It makes it easy
to set your view controllers up in a proper key application window by providing the following methods:

```swift
// Takes a `UIViewController`,  makes it the test app key window's root, and kicks off its lifecycle.
Fleet.setAsAppRootWindow(_:)

// Takes a `UIViewController`,  makes it the root of a navigation stack, kicks off the lifecycle, and
// returns the navigation controller that hosts that view controller.
Fleet.setInAppWindowRootNavigation(_:)
```

Fleet highly recommends that all view controller tests run inside the test host's key window using one of the above
methods. For more discussion on why, go to [the relevant section in the FAQ](./Documentation/FAQ.md#why-should-i-make-sure-all-uiviewcontroller-tests-happen-in-a-uiwindow).

## FAQ
- [Does Fleet do lots of swizzling to provide its features?](./Documentation/FAQ.md#does-fleet-do-lots-of-swizzling-to-provide-its-features)
- [I could accomplish the same thing by calling all the delegate methods and events myself, right?](./Documentation/FAQ.md#i-could-accomplish-the-same-thing-by-calling-all-the-delegate-methods-and-events-myself-right)
- [Why does Fleet throw errors for almost all its interactions with UIKit?](./Documentation/FAQ.md#why-does-fleet-throw-errors-for-almost-all-its-interactions-with-uikit)
- [Why should I make sure all UIViewController unit tests happen in a UIWindow?](./Documentation/FAQ.md#why-should-i-make-sure-all-uiviewcontroller-tests-happen-in-a-uiwindow)
