import UIKit

class KittensNavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        performSegue(withIdentifier: "ShowKittenImage", sender: nil)
    }
}
