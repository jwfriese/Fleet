import UIKit

class HomeScreenViewController: UIViewController {
    @IBOutlet weak var loadingStatusLabel: UILabel?
    @IBOutlet weak var makeAlertAppearButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        loadingStatusLabel?.text = "Finished loading!"
    }

    @IBAction func makeAlertAppear() {

    }
}

