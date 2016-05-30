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
}
