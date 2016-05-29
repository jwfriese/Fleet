import XCTest
import Fleet
import Nimble
@testable import FleetTestApp

class UIStoryboard_FleetSpec: XCTestCase {
    var turtleStoryboard: UIStoryboard!
    
    class MockBoxedTurtleViewController: BoxTurtleViewController { }
    class MockCrabViewController: CrabViewController { }
    class MockPuppyListViewController: PuppyListViewController { }
    
    override func setUp() {
        super.setUp()
        
        turtleStoryboard = UIStoryboard.init(name: "TurtlesStoryboard", bundle: nil)
    }
    
    func testBindingViewControllerToIdentifierSameStoryboard() {
        let mockBoxedTurtleViewController = MockBoxedTurtleViewController()
        turtleStoryboard.bindViewController(mockBoxedTurtleViewController, toIdentifier: "BoxTurtleViewController")
        
        let boxedTurtleViewController = turtleStoryboard.instantiateViewControllerWithIdentifier("BoxTurtleViewController")
        expect(boxedTurtleViewController).to(beIdenticalTo(mockBoxedTurtleViewController))
    }
    
    func testBindingViewControllerToIdentifierReferenceToAnotherStoryboard() {
        let mockCrabViewController = MockCrabViewController()
        turtleStoryboard.bindViewController(mockCrabViewController, toIdentifier: "CrabViewController", forReferencedStoryboardWithName: "CrabStoryboard")
        
        let testNavigationController = TestNavigationController()
        
        let animalListViewController = turtleStoryboard.instantiateInitialViewController() as? AnimalListViewController
        testNavigationController.pushViewController(animalListViewController!, animated: false)
        
        animalListViewController?.goToCrab()
        
        expect(testNavigationController.topViewController).to(beIdenticalTo(mockCrabViewController))
    }
    
    func testBindingViewControllerToInitialViewControllerOfReferenceToAnotherStoryboard() {
        let mockPuppyListViewController = MockPuppyListViewController()
        
        turtleStoryboard.bindViewController(mockPuppyListViewController, asInitialViewControllerForReferencedStoryboardWithName: "PuppyStoryboard")
        
        let testNavigationController = TestNavigationController()
        
        let animalListViewController = turtleStoryboard.instantiateInitialViewController() as? AnimalListViewController
        testNavigationController.pushViewController(animalListViewController!, animated: false)
        
        animalListViewController?.goToPuppy()
        
        expect(testNavigationController.topViewController).to(beIdenticalTo(mockPuppyListViewController))
    }
}
