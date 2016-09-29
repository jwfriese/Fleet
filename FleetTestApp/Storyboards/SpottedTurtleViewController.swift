import UIKit

class SpottedTurtleViewController: UIViewController {
    @IBOutlet weak var alertButtonOne: UIButton?
    @IBOutlet weak var alertButtonTwo: UIButton?
    @IBOutlet weak var informationalLabel: UILabel?

    @IBAction func showAlertWithAlertStyle() {
        let alertController = UIAlertController(title: "SPOTTED TURTLE ALERT 1", message: "don't worry the spots aren't dangerous... FOR ME", preferredStyle: .alert)

        let alertAction = UIAlertAction(title: "Pick Up Anyway", style: .default) { action in
            self.informationalLabel?.text = "WAIT NO PUT ME DOWN"
        }

        alertController.addAction(alertAction)

        let dismissAction = UIAlertAction(title: "Cower", style: .cancel, handler: nil)
        alertController.addAction(dismissAction)

        present(alertController, animated: true, completion: nil)
    }

    @IBAction func showAlertWithActionSheetStyle() {
        let alertController = UIAlertController(title: "SPOTTED TURTLE ALERT 2", message: "press one of the buttons on this alert if you date... I mean dare", preferredStyle: .actionSheet)

        let alertAction = UIAlertAction(title: "Offer Carrot as Tribute", style: .default) { action in
            self.informationalLabel?.text = "This gift pleases me I will spare you for now"
            self.dismiss(animated: true, completion: nil)
        }

        alertController.addAction(alertAction)

        let dismissAction = UIAlertAction(title: "Don't Date", style: .cancel) { action in
            self.dismiss(animated: true, completion: nil)

        }

        alertController.addAction(dismissAction)

        present(alertController, animated: true, completion: nil)
    }
}
