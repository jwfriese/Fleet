import XCTest
import Fleet
import Nimble

@testable import FleetTestApp

fileprivate class TestTarget: NSObject {
    var didCallAction = false

    func action() {
        didCallAction = true
    }
}

class UIBarButtonItem_FleetSpec: XCTestCase {
    var subject: UIBarButtonItem!
    fileprivate var testTarget: TestTarget!

    override func setUp() {
        let viewController = UIViewController()
        let navigationController = UINavigationController(rootViewController: viewController)

        testTarget = TestTarget()
        subject = UIBarButtonItem(title: "turtles", style: .plain, target: testTarget, action: #selector(TestTarget.action))
        navigationController.navigationItem.rightBarButtonItem = subject
        Fleet.setAsAppWindowRoot(navigationController)
    }

    func test_tap_performsButtonAction() {
        try! subject.tap()
        expect(self.testTarget.didCallAction).to(beTrue())
    }

    func test_tap_whenNotEnabled_throwsError() {
        subject.isEnabled = false
        expect { try self.subject.tap() }.to(throwError { (error: Fleet.BarButtonItemError) in
            expect(error.description).to(equal("Cannot tap UIBarButtonItem: Control is not enabled."))
        })
    }

    func test_tap_whenNoTarget_throwsError() {
        subject.target = nil
        expect { try self.subject.tap() }.to(throwError { (error: Fleet.BarButtonItemError) in
            expect(error.description).to(equal("Attempted to tap UIBarButtonItem (title='turtles') with no associated target."))
        })
    }
}
