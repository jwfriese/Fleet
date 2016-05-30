import XCTest
import Fleet
import Nimble

class UIViewController_FleetSpec: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    func test_presentViewController_immediatelyPresentsTheViewController() {
        let bottom = UIViewController()
        let top = UIViewController()
        
        bottom.presentViewController(top, animated: true, completion: nil)
        
        expect(bottom.presentedViewController).to(beIdenticalTo(top))
        expect(top.presentingViewController).to(beIdenticalTo(bottom))
    }
    
    func test_dismissViewController_immediatelyDismissesThePresentedViewController() {
        let bottom = UIViewController()
        let top = UIViewController()
        
        bottom.presentViewController(top, animated: true, completion: nil)
        
        bottom.dismissViewControllerAnimated(true, completion: nil)
        expect(bottom.presentedViewController).to(beNil())
        expect(top.presentingViewController).to(beNil())
    }
    
    func test_presentViewController_immediatelyExecutesTheGivenCompletionHandler() {
        let bottom = UIViewController()
        let top = UIViewController()
        
        var didFireCompletionHandler = false
        let completionHanlder = {
            didFireCompletionHandler = true
        }
        
        bottom.presentViewController(top, animated: true, completion: completionHanlder)
        
        expect(didFireCompletionHandler).to(beTrue())
    }
}
