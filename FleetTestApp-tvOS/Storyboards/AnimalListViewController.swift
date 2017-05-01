import UIKit

class AnimalListViewController: UIViewController {
    @IBOutlet weak var boxTurtleButton: UIButton?
    @IBOutlet weak var spottedTurtleButton: UIButton?
    @IBOutlet weak var crabButton: UIButton?
    @IBOutlet weak var crab2Button: UIButton?
    @IBOutlet weak var puppyButton: UIButton?

    @IBAction func goToBoxTurtle() {
        performSegue(withIdentifier: "ShowBoxTurtle", sender: nil)
    }

    @IBAction func goToSpottedTurtle() {
        performSegue(withIdentifier: "ShowSpottedTurtle", sender: nil)
    }

    @IBAction func goToCrab() {
        performSegue(withIdentifier: "ShowCrab", sender: nil)
    }

    @IBAction func goToCrab2() {
        performSegue(withIdentifier: "ShowCrab2", sender: nil)
    }

    @IBAction func goToPuppy() {
        performSegue(withIdentifier: "ShowPuppy", sender: nil)
    }
}
