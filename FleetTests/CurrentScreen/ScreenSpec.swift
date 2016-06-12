import XCTest
import Nimble
@testable import Fleet
@testable import FleetTestApp

class ScreenSpec: XCTestCase {
    var subject: FLTScreen!
    var storyboard: UIStoryboard!
    var viewControllerThatPresentsAlerts: SpottedTurtleViewController!

    override func setUp() {
        super.setUp()
        
        subject = Fleet.getCurrentScreen()
        
        storyboard = UIStoryboard.init(name: "TurtlesAndFriendsStoryboard", bundle: nil)
        viewControllerThatPresentsAlerts = storyboard.instantiateViewControllerWithIdentifier("SpottedTurtleViewController") as! SpottedTurtleViewController
        
        Fleet.swapWindowRootViewController(viewControllerThatPresentsAlerts)
    }
    
    func test_topmostPresentedViewController_returnsTopmostPresentedViewController() {
        expect(self.subject.topmostPresentedViewController).to(beIdenticalTo(viewControllerThatPresentsAlerts))
        
        let newTopmostViewController = UIViewController()
        viewControllerThatPresentsAlerts.presentViewController(newTopmostViewController, animated: true, completion: nil)
        
        expect(self.subject.topmostPresentedViewController).to(beIdenticalTo(newTopmostViewController))
    }
    
    func test_presentedAlert_whenNoAlertIsPresented_returnsNil() {
        expect(self.subject.presentedAlert).to(beNil())
    }
    
    func test_presentedAlert_whenAnAlertIsPresented_whenAlertIsAlertStyle_returnsTheAlert() {
        viewControllerThatPresentsAlerts.alertButtonOne?.tap()
        expect(self.subject.presentedAlert).toNot(beNil())
    }
}
