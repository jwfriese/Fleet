import XCTest
import Fleet
import Nimble

class UISwitch_FleetSpec: XCTestCase {
    func test_flip_whenSwitchIsVisibleAndEnabled_togglesTheValueOfTheSwitch() {
        let subject = UISwitch()
        subject.isHidden = false
        subject.isEnabled = true
        expect(subject.isOn).to(beFalse())

        try! subject.flip()
        expect(subject.isOn).to(beTrue())

        try! subject.flip()
        expect(subject.isOn).to(beFalse())
    }

    func test_flip_whenUserInteractionIsNotEnabled_doesNotChangeTheSwitchAndThrowsError() {
        let subject = UISwitch()
        subject.isHidden = false
        subject.isEnabled = true
        subject.isUserInteractionEnabled = false
        expect(subject.isOn).to(beFalse())

        expect { try subject.flip() }.to(throwError { (error: Fleet.SwitchError) in
            expect(error.description).to(equal("Cannot flip UISwitch: View does not allow user interaction."))
        })
        expect(subject.isOn).to(beFalse())
    }

    func test_flip_whenSwitchIsNotVisible_doesNotChangeTheSwitchAndThrowsError() {
        let subject = UISwitch()
        subject.isHidden = true
        subject.isEnabled = true
        expect(subject.isOn).to(beFalse())

        expect { try subject.flip() }.to(throwError { (error: Fleet.SwitchError) in
            expect(error.description).to(equal("Cannot flip UISwitch: Control is not visible."))
        })
        expect(subject.isOn).to(beFalse())
    }

    func test_flip_whenSwitchIsNotEnabled_doesNotChangeTheSwitchAndThrowsError() {
        let subject = UISwitch()
        subject.isHidden = false
        subject.isEnabled = false
        expect(subject.isOn).to(beFalse())

        expect { try subject.flip() }.to(throwError { (error: Fleet.SwitchError) in
            expect(error.description).to(equal("Cannot flip UISwitch: Control is not enabled."))
        })
        expect(subject.isOn).to(beFalse())
    }

    fileprivate class SwitchCallbackTarget: NSObject {
        var capturedSwitch: UISwitch?

        func onSwitchValueChanged(sender: UISwitch) {
            capturedSwitch = sender
        }
    }

    func test_flip_callsActionsBoundToControlEvent() {
        let subject = UISwitch()
        subject.isHidden = false
        subject.isEnabled = true

        let callbackTarget = SwitchCallbackTarget()
        subject.addTarget(callbackTarget, action: #selector(SwitchCallbackTarget.onSwitchValueChanged(sender:)), for: .valueChanged)

        try! subject.flip()
        expect(callbackTarget.capturedSwitch).to(beIdenticalTo(subject))
    }
}
