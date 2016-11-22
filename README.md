# Fleet [![Build Status](https://travis-ci.org/jwfriese/Fleet.svg?branch=master)](https://travis-ci.org/jwfriese/Fleet) 
Fleet is a UIKit-focused testing framework intended for use on iOS projects written in Swift.

## Installation

See the [Installation section](./Documentation/Installation.md) for details about installing Fleet in your project.  

## Features
Fleet extends UIKit classes in order to make it easier to test your code's interactions with UIKit. Following are summaries of the major features for each extended class. The [Documentation folder](./Documentation) contains more information about these features, as well as sample code showing you how they are intended to be used.

- [UIStoryboard](./Documentation/UIStoryboard.md) - Supports mocking of and injection into elements on a storyboard. It even supports injection into storyboard references.
- [UIViewController](./Documentation/UIViewController.md) - Allows specs to test view controller presentation and dismissal without waiting for the UI run-loop.
- [UITableView](./Documentation/UITableView.md) - Provides methods mimicing user actions on table views, ensuring all appropriate delegate and data source callbacks are run.
- [UINavigationController](./Documentation/UINavigationController.md) - Allows specs to test pushing and popping on the navigation stack without waiting for the UI run-loop.
- [UIButton](./Documentation/UIButton.md) - Provides convenience methods for interacting with buttons in test.
- [UIBarButtonItem](./Documentation/UIBarButtonItem.md) - Provides convenience methods similar to those provided for UIButton.
- [UIAlertController](./Documentation/UIAlertController.md) - Allows specs to simply tap on alert actions in order to test their behavior
- [UITextField](./Documentation/UITextField.md) - Provides convenience methods for entering text
