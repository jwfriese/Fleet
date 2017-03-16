import UIKit

class HomeScreenViewController: UIViewController {
    @IBOutlet weak var loadingStatusLabel: UILabel?
    @IBOutlet weak var goToAlertPageButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        loadingStatusLabel?.text = "Finished loading!"
    }

    @IBAction private func goToAlertPage() {
        performSegue(withIdentifier: "ShowAlertPage", sender: nil)
    }
}

