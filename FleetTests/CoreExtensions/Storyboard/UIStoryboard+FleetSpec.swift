import XCTest
import Fleet
import Nimble

class UIStoryboard_FleetSpec: XCTestCase {
    var turtleStoryboard: UIStoryboard!
    
    class MockBoxedTurtleViewController: BoxTurtleViewController { }
    class MockCrabViewController: CrabViewController { }
    
    override func setUp() {
        super.setUp()
        
        turtleStoryboard = UIStoryboard.init(name: "TurtlesStoryboard", bundle: NSBundle.currentTestBundle)
    }
    
    func testBindingViewControllerToIdentifierSameStoryboard() {
        let mockBoxedTurtleViewController = MockBoxedTurtleViewController()
        turtleStoryboard.bindViewController(mockBoxedTurtleViewController, toIdentifier: "BoxTurtleViewController")
        
        let boxedTurtleViewController = turtleStoryboard.instantiateViewControllerWithIdentifier("BoxTurtleViewController")
        expect(boxedTurtleViewController).to(beIdenticalTo(mockBoxedTurtleViewController))
    }
    
    func testBindingViewControllerToIdentifierReferenceToAnotherStoryboard() {
        let mockCrabViewController = MockCrabViewController()
        turtleStoryboard.bindViewController(mockCrabViewController, toIdentifier: "CrabViewController", fromStoryboardWithName: "CrabStoryboard")
        
        let testNavigationController = TestNavigationController()
        
        let turtleMenuController = turtleStoryboard.instantiateInitialViewController() as? TurtleMenuViewController
        testNavigationController.pushViewController(turtleMenuController!, animated: false)
        
        turtleMenuController?.goToCrab()
        
        expect(testNavigationController.topViewController).to(beIdenticalTo(mockCrabViewController))
    }
}
