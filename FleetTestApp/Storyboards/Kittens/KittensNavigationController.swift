import UIKit

class KittensNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        performSegueWithIdentifier("ShowKittenImage", sender: nil)
    }
}
