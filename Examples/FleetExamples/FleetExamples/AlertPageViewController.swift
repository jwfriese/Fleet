import UIKit

class AlertPageViewController: UIViewController {
    @IBOutlet weak var showAlertButton: UIButton?

    @IBAction private func showAlert() {
        let alert = UIAlertController(
            title: "Alert Title",
            message: "An alert has appeared",
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(
                title: "OK",
                style: .cancel,
                handler: nil
            )
        )

        self.present(alert, animated: true, completion: nil)
    }
}

