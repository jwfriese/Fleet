import UIKit

class CorgiViewController: UIViewController {
    @IBOutlet weak var showCorgiOneButton: UIButton?
    @IBOutlet weak var showCorgiTwoButton: UIButton?
    @IBOutlet weak var corgiImageView: UIImageView?

    var viewDidLoadCallCount: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        viewDidLoadCallCount += 1
    }

    @IBAction func showCorgiOne() {
        corgiImageView?.image = UIImage(named: "corgi-one")
    }

    @IBAction func showCorgiTwo() {
        corgiImageView?.image = UIImage(named: "corgi-two")
    }
}
