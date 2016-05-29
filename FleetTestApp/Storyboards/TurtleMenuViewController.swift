import UIKit

class TurtleMenuViewController: UIViewController {
    @IBOutlet weak var boxTurtleButton: UIButton?
    @IBOutlet weak var spottedTurtleButton: UIButton?
    @IBOutlet weak var crabButton: UIButton?
    
    @IBAction func goToBoxTurtle() {
        performSegueWithIdentifier("ShowBoxTurtle", sender: nil)
    }
    
    @IBAction func goToSpottedTurtle() {
        performSegueWithIdentifier("ShowSpottedTurtle", sender: nil)
    }
    
    @IBAction func goToCrab() {
        performSegueWithIdentifier("ShowCrab", sender: nil)
    }
}
