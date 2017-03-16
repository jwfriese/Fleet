import UIKit

class AlertPageViewController: UIViewController {
    @IBOutlet weak var showAlertButton: UIButton?

    @IBAction private func showAlert() {
        let alert = UIAlertController(
            title: "Alert Title",
            message: "An alert has appeared",
            preferredStyle: .alert
        )

        self.present(alert, animated: true, completion: nil)
    }
}

