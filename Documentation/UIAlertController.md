## UIAlertController

Unit testing the behavior of buttons on UIAlertControllers has always been a challenge. Fleet aims to erase this pain by providing a way to "tap" on alert actions in-test to fire their associated handlers. 

Suppose you have an alert controller in code that is set up like this:
```swift
let alertController = UIAlertController(title: "Some Alert", message: "This is a regular old alert", preferredStyle: .alert)
let someAction = UIAlertAction(title: "Some Action", style: .default) { action in
    // Do some stuff in here
}

alertController.addAction(someAction)
```     
With Fleet, you can unit test the stuff that happens in that action much more easily than before. With one simple line of code, that action's handler will be fired:
```swift
alertController.tapAlertAction(withTitle: "Some Action")

// Now you can make any assertions you'd like on the behavior of that action. 
```

