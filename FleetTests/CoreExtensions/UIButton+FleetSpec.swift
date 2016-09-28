import XCTest
import Fleet
import Nimble

class UIButton_FleetSpec: XCTestCase {
    var buttonTapTestViewController: ButtonTapTestViewController?

    override func setUp() {
        super.setUp()

        buttonTapTestViewController = ButtonTapTestViewController(nibName: "ButtonTapTestViewController", bundle: Bundle.currentTestBundle)
        _ = buttonTapTestViewController?.view
    }

    func testCallingTapOnButton() {
        buttonTapTestViewController?.testButton?.tap()
        buttonTapTestViewController?.changeLabel()

        expect(self.buttonTapTestViewController?.testLabel?.text).toEventually(equal("some test label"))
    }
}
