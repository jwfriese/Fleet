import UIKit

class ButtonTapTestViewController: UIViewController {
    @IBOutlet weak var testLabel: UILabel?
    @IBOutlet weak var testButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        testLabel?.text = ""
    }

    @IBAction func changeLabel() {
        testLabel?.text = "some test label"
    }
}
