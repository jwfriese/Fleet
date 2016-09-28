import UIKit

class PuppyListViewController: UIViewController {
    @IBOutlet weak var showPuppiesListButton: UIButton?
    @IBOutlet weak var corgiButton: UIButton?
    @IBOutlet weak var malteseButton: UIButton?
    @IBOutlet weak var frenchBulldogButton: UIButton?
    @IBOutlet weak var basenjiButton: UIButton?

    @IBAction func showPuppiesList() {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1.5 * Double(NSEC_PER_SEC))),
            dispatch_get_main_queue()) {
            self.revealPuppies()
        }
    }

    fileprivate func revealPuppies() {
        corgiButton?.isHidden = false
        malteseButton?.isHidden = false
        frenchBulldogButton?.isHidden = false
        basenjiButton?.isHidden = false
    }
}
