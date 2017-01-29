# FAQ
## Does Fleet do lots of swizzling to provide its features?
The short answer is yes, Fleet swizzles.

That said, the Fleet team puts a lot of effort into ensuring that swizzling to _change UIKit behavior_
is kept to a minimum. Most swizzling within Fleet is there to add behavior into a UIKit flow.

Here is an exhaustive list of behavior-altering swizzles used by Fleet:
- Swizzling `UIViewController` and `UINavigationController` presentation methods to turn off animations
This swizzling is done to make the processing of transitions between view controllers more
consistent between tests. Fleet explicitly stops short of forcing transitions to happen
immediately with swizzling -- your tests will still have to let the UI thread finish processing.

