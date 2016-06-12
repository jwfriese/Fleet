import UIKit

class SpottedTurtleViewController: UIViewController {
    @IBOutlet weak var alertButtonOne: UIButton?
    @IBOutlet weak var alertButtonTwo: UIButton?
    @IBOutlet weak var informationalLabel: UILabel?
    
    @IBAction func showAlertWithAlertStyle() {
        let alertController = UIAlertController(title: "SPOTTED TURTLE ALERT 1", message: "don't worry the spots aren't dangerous... FOR ME", preferredStyle: .Alert)
        
        let alertAction = UIAlertAction(title: "Pick Up Anyway", style: .Default) { action in
            self.informationalLabel?.text = "WAIT NO PUT ME DOWN"
            self.dismissViewControllerAnimated(true, completion: nil)
        }
        
        alertController.addAction(alertAction)
        
        let dismissAction = UIAlertAction(title: "Cower", style: .Cancel) { action in
            self.dismissViewControllerAnimated(true, completion: nil)
        }
        
        alertController.addAction(dismissAction)
        
        presentViewController(alertController, animated: true, completion: nil)
    }
    
    @IBAction func showAlertWithActionSheetStyle() {
        let alertController = UIAlertController(title: "SPOTTED TURTLE ALERT 2", message: "press one of the buttons on this alert if you date... I mean dare", preferredStyle: .ActionSheet)
        
        let alertAction = UIAlertAction(title: "Offer Carrot as Tribute", style: .Default) { action in
            self.informationalLabel?.text = "This gift pleases me I will spare you for now"
            self.dismissViewControllerAnimated(true, completion: nil)
        }
        
        alertController.addAction(alertAction)
        
        let dismissAction = UIAlertAction(title: "Don't Date", style: .Cancel) { action in
            self.dismissViewControllerAnimated(true, completion: nil)
            
        }
        
        alertController.addAction(dismissAction)
        
        presentViewController(alertController, animated: true, completion: nil)
    }
}
