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

        try! subject.tap()
        expect(callbackTarget.capturedButton).to(beIdenticalTo(subject))
    }

    func test_tap_whenButtonIsNotVisible_doesNothingAndThrowsError() {
        let subject = UIButton()
        subject.isHidden = true
        subject.isEnabled = true

        let callbackTarget = ButtonCallbackTarget()
        subject.addTarget(callbackTarget, action: #selector(ButtonCallbackTarget.onButtonTapped(sender:)), for: .touchUpInside)

        expect { try subject.tap() }.to(throwError { (error: Fleet.ButtonError) in
            expect(error.description).to(equal("Cannot tap UIButton: Control is not visible."))
        })
        expect(callbackTarget.capturedButton).to(beNil())
    }

    func test_tap_whenButtonIsNotEnabled_doesNothingAndThrowsError() {
        let subject = UIButton()
        subject.isHidden = false
        subject.isEnabled = false

        let callbackTarget = ButtonCallbackTarget()
        subject.addTarget(callbackTarget, action: #selector(ButtonCallbackTarget.onButtonTapped(sender:)), for: .touchUpInside)

        expect { try subject.tap() }.to(throwError { (error: Fleet.ButtonError) in
            expect(error.description).to(equal("Cannot tap UIButton: Control is not enabled."))
        })
        expect(callbackTarget.capturedButton).to(beNil())
    }

    func test_tap_whenButtonDoesNotAllowUserInteraction_doesNothingAndThrowsError() {
        let subject = UIButton()
        subject.isHidden = false
        subject.isEnabled = true
        subject.isUserInteractionEnabled = false

        let callbackTarget = ButtonCallbackTarget()
        subject.addTarget(callbackTarget, action: #selector(ButtonCallbackTarget.onButtonTapped(sender:)), for: .touchUpInside)

        expect { try subject.tap() }.to(throwError { (error: Fleet.ButtonError) in
            expect(error.description).to(equal("Cannot tap UIButton: View does not allow user interaction."))
        })
        expect(callbackTarget.capturedButton).to(beNil())
    }
}
