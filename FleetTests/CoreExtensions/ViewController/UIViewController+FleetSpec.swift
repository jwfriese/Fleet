import XCTest
import Fleet
import Nimble

class UIViewController_FleetSpec: XCTestCase {
    fileprivate class TestViewController: UIViewController {
        var testViewDidLoadCallCount: UInt = 0

        fileprivate override func viewDidLoad() {
            super.viewDidLoad()
            testViewDidLoadCallCount += 1
        }
    }

    func test_presentViewController_immediatelyPresentsTheViewController() {
        let bottom = UIViewController()
        Fleet.setAsAppWindowRoot(bottom)
        let top = UIViewController()

        bottom.present(top, animated: true, completion: nil)

        expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beIdenticalTo(top))
    }

    func test_presentViewController_executesTheGivenCompletionHandlerAfterPresentationFinishes() {
        let bottom = UIViewController()
        Fleet.setAsAppWindowRoot(bottom)
        let top = UIViewController()

        var didCompletionHandlerFireAfterPresenting = false
        let completionHandler = {
            if Fleet.getApplicationScreen()?.topmostViewController === top {
                didCompletionHandlerFireAfterPresenting = true
            }
        }

        bottom.present(top, animated: true, completion: completionHandler)

        expect(didCompletionHandlerFireAfterPresenting).toEventually(beTrue())
    }

    func test_dismissViewController_dismissesThePresentedViewControllerAndFiresExecutionHandlerAfterDismiss() {
        let bottom = UIViewController()
        Fleet.setAsAppWindowRoot(bottom)
        let top = UIViewController()

        var didPresentSuccessfully = false
        bottom.present(top, animated: true) {
            if Fleet.getApplicationScreen()?.topmostViewController === top {
                didPresentSuccessfully = true
            }
        }

        var didDismissPresentedController = false
        bottom.dismiss(animated: true) {
            if didPresentSuccessfully && Fleet.getApplicationScreen()?.topmostViewController === bottom {
                didDismissPresentedController = true
            }
        }

        expect(didDismissPresentedController).toEventually(beTrue())
    }

    func test_showViewController_immediatelyPresentsTheViewController() {
        let bottom = UIViewController()
        Fleet.setAsAppWindowRoot(bottom)
        let top = UIViewController()

        bottom.show(top, sender: nil)

        expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beIdenticalTo(top))
    }

    func test_presentViewController_immediatelyLoadsThePresentedViewController() {
        let bottom = UIViewController()
        Fleet.setAsAppWindowRoot(bottom)
        let top = TestViewController()

        bottom.present(top, animated: true, completion: nil)
        expect(top.testViewDidLoadCallCount).to(equal(1))
    }

    func test_presentViewController_doesNotLoadPresentedViewControllerMultipleTimes() {
        let bottom = UIViewController()
        Fleet.setAsAppWindowRoot(bottom)
        let top = TestViewController()

        bottom.present(top, animated: true, completion: nil)
        expect(top.testViewDidLoadCallCount).toEventuallyNot(beGreaterThan(1))
    }
}
