import XCTest
import Fleet
import Nimble

#if os(iOS)
    @testable import FleetTestApp
#elseif os(tvOS)
    @testable import FleetTestApp_tvOS
#endif

fileprivate class TestTarget: NSObject {
    var didCallAction = false

    @objc func action() {
        didCallAction = true
    }
}

class UIBarButtonItem_FleetSpec: XCTestCase {
    var subject: UIBarButtonItem!
    fileprivate var testTarget: TestTarget!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        let viewController = UIViewController()
        let navigationController = UINavigationController(rootViewController: viewController)

        testTarget = TestTarget()
        subject = UIBarButtonItem(title: "turtles", style: .plain, target: testTarget, action: #selector(TestTarget.action))
        navigationController.navigationItem.rightBarButtonItem = subject
        Fleet.setAsAppWindowRoot(navigationController)
    }

    func test_tap_performsButtonAction() {
        subject.tap()
        expect(self.testTarget.didCallAction).to(beTrue())
    }

    func test_tap_whenNotEnabled_raisesException() {
        subject.isEnabled = false
        expect { self.subject.tap() }.to(
            raiseException(named: "Fleet.BarButtonItemError", reason: "Cannot tap UIBarButtonItem: Control is not enabled.", userInfo: nil, closure: nil)
        )
    }

    func test_tap_whenNoTarget_raisesException() {
        subject.target = nil
        expect { self.subject.tap() }.to(
            raiseException(named: "Fleet.BarButtonItemError", reason: "Attempted to tap UIBarButtonItem (title='turtles') with no associated target.", userInfo: nil, closure: nil)
        )
    }

    func test_tap_whenNoAction_raisesException() {
        subject.action = nil
        expect { self.subject.tap() }.to(
            raiseException(named: "Fleet.BarButtonItemError", reason: "Attempted to tap UIBarButtonItem (title='turtles') with no associated action.", userInfo: nil, closure: nil)
        )
    }
}
