import XCTest
import Fleet
import Nimble

@testable import FleetTestApp

class UIBarButtonItem_FleetSpec: XCTestCase {
    var turtlesAndFriendsStoryboard: UIStoryboard!
    
    override func setUp() {
        super.setUp()
        turtlesAndFriendsStoryboard = UIStoryboard.init(name: "TurtlesAndFriendsStoryboard", bundle: nil)
    }
    
    func test_tap_directlyOnBarButtonItem() {
        let boxTurtleViewController = turtlesAndFriendsStoryboard.instantiateViewControllerWithIdentifier("BoxTurtleViewController") as? BoxTurtleViewController
        boxTurtleViewController?.view
        
        boxTurtleViewController?.rightBarButtonItem?.tap()
        
        expect(boxTurtleViewController?.informationLabel?.text).to(equal("BOX TURTLE DANCE PARTY"))
    }
}
