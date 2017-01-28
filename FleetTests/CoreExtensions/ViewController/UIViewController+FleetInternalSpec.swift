import XCTest
import Nimble

@testable import Fleet

class UIViewController_FleetInternalSpec: XCTestCase {
    func test_viewDidLoadCallCountProperty_beforeTheViewControllerViewLoads_returns0() {
        let viewController = UIViewController()
        expect(viewController.viewDidLoadCallCount).to(equal(0))
    }

    func test_viewDidLoadCallCountProperty_onceTheViewLoads_returns1() {
        let viewController = UIViewController()
        Fleet.setAsAppWindowRoot(viewController)
        expect(viewController.viewDidLoadCallCount).to(equal(1))
    }

    func test_viewDidLoadCallCountProperty_returnsTheNumberOfTimesViewDidLoadIsCalled() {
        let viewController = UIViewController()
        viewController.viewDidLoad()
        viewController.viewDidLoad()
        viewController.viewDidLoad()
        viewController.viewDidLoad()
        expect(viewController.viewDidLoadCallCount).to(equal(4))
    }
}
