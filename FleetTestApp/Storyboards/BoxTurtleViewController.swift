import UIKit

class BoxTurtleViewController: UIViewController {
    @IBOutlet weak var boxTurtleImage: UIImageView?
    @IBOutlet weak var leftBarButtonItem: UIBarButtonItem?
    @IBOutlet weak var rightBarButtonItem: UIBarButtonItem?
    @IBOutlet weak var informationLabel: UILabel?
    
    @IBAction func onLeftBarButtonItemTapped() {
        informationLabel?.text = "box turtle stop party..."
    }
    
    @IBAction func onRightBarButtonItemTapped() {
        informationLabel?.text = "BOX TURTLE DANCE PARTY"
        
        doTurtleDanceParty()
    }
    
    private func doTurtleDanceParty() {
        if let boxTurtleImage = boxTurtleImage {
            let path = UIBezierPath()
            
            let startingPoint = CGPoint(x: boxTurtleImage.frame.origin.x + (boxTurtleImage.frame.size.width / 2),
                                        y: boxTurtleImage.frame.origin.y + (boxTurtleImage.frame.size.height / 2)
            )
            let rightPoint = CGPoint(x: startingPoint.x + 30, y: startingPoint.y)
            let rightMoveControlLeft = CGPoint(x: startingPoint.x, y: startingPoint.y - 30)
            let rightMoveControlRight = CGPoint(x: startingPoint.x + 30, y: startingPoint.y - 30)
            
            let leftPoint = CGPoint(x: startingPoint.x - 30, y: startingPoint.y)
            let leftMoveControlLeft = CGPoint(x: startingPoint.x - 30, y: startingPoint.y - 30)
            let leftMoveControlRight = CGPoint(x: startingPoint.x, y: startingPoint.y - 30)
            
            path.moveToPoint(startingPoint)
            path.addCurveToPoint(rightPoint, controlPoint1: rightMoveControlLeft, controlPoint2: rightMoveControlRight)
            path.addCurveToPoint(startingPoint, controlPoint1: rightMoveControlRight, controlPoint2: rightMoveControlLeft)
            
            path.addCurveToPoint(leftPoint, controlPoint1: leftMoveControlRight, controlPoint2: leftMoveControlLeft)
            path.addCurveToPoint(startingPoint, controlPoint1: leftMoveControlLeft, controlPoint2: leftMoveControlRight)
            
            let animation = CAKeyframeAnimation(keyPath: "position")
            animation.path = path.CGPath
            animation.duration = 1.5
            animation.repeatCount = 10
            
            boxTurtleImage.layer.addAnimation(animation, forKey: "TURTLE DANCE PARTY")
        }
    }
}
