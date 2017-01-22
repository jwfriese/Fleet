import XCTest
import Fleet
import Nimble

class UIButton_FleetSpec: XCTestCase {
    fileprivate class ButtonCallbackTarget: NSObject {
        var capturedButton: UIButton?

        func onButtonTapped(sender: UIButton) {
            capturedButton = sender
        }
    }

    func test_tap_whenButtonIsVisibleAndEnabled_tapsTheButton() {
        let subject = UIButton()
        subject.isHidden = false
        subject.isEnabled = true

        let callbackTarget = ButtonCallbackTarget()
        subject.addTarget(callbackTarget, action: #selector(ButtonCallbackTarget.onButtonTapped(sender:)), for: .touchUpInside)

        subject.tap()
        expect(callbackTarget.capturedButton).to(beIdenticalTo(subject))
    }
}
