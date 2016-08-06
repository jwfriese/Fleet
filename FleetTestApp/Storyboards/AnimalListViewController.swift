import UIKit

class AnimalListViewController: UIViewController {
    @IBOutlet weak var boxTurtleButton: UIButton?
    @IBOutlet weak var spottedTurtleButton: UIButton?
    @IBOutlet weak var crabButton: UIButton?
    @IBOutlet weak var crab2Button: UIButton?
    @IBOutlet weak var puppyButton: UIButton?

    @IBAction func goToBoxTurtle() {
        performSegueWithIdentifier("ShowBoxTurtle", sender: nil)
    }

    @IBAction func goToSpottedTurtle() {
        performSegueWithIdentifier("ShowSpottedTurtle", sender: nil)
    }

    @IBAction func goToCrab() {
        performSegueWithIdentifier("ShowCrab", sender: nil)
    }

    @IBAction func goToCrab2() {
        performSegueWithIdentifier("ShowCrab2", sender: nil)
    }

    @IBAction func goToPuppy() {
        performSegueWithIdentifier("ShowPuppy", sender: nil)
    }
}
