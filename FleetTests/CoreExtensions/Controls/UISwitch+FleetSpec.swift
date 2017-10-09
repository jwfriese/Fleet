import XCTest
import Fleet
import Nimble

class UISwitch_FleetSpec: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_flip_whenSwitchIsVisibleAndEnabled_togglesTheValueOfTheSwitch() {
        let subject = UISwitch()
        subject.isHidden = false
        subject.isEnabled = true
        expect(subject.isOn).to(beFalse())

        subject.flip()
        expect(subject.isOn).to(beTrue())

        subject.flip()
        expect(subject.isOn).to(beFalse())
    }

    func test_flip_whenUserInteractionIsNotEnabled_doesNotChangeTheSwitchAndRaisesException() {
        let subject = UISwitch()
        subject.isHidden = false
        subject.isEnabled = true
        subject.isUserInteractionEnabled = false
        expect(subject.isOn).to(beFalse())

        expect { subject.flip() }.to(
            raiseException(named: "Fleet.SwitchError", reason: "Cannot flip UISwitch: View does not allow user interaction.", userInfo: nil, closure: nil)
        )
        expect(subject.isOn).to(beFalse())
    }

    func test_flip_whenSwitchIsNotVisible_doesNotChangeTheSwitchAndRaisesException() {
        let subject = UISwitch()
        subject.isHidden = true
        subject.isEnabled = true
        expect(subject.isOn).to(beFalse())

        expect { subject.flip() }.to(
            raiseException(named: "Fleet.SwitchError", reason: "Cannot flip UISwitch: Control is not visible.", userInfo: nil, closure: nil)
        )
        expect(subject.isOn).to(beFalse())
    }

    func test_flip_whenSwitchIsNotEnabled_doesNotChangeTheSwitchAndRaisesException() {
        let subject = UISwitch()
        subject.isHidden = false
        subject.isEnabled = false
        expect(subject.isOn).to(beFalse())

        expect { subject.flip() }.to(
            raiseException(named: "Fleet.SwitchError", reason: "Cannot flip UISwitch: Control is not enabled.", userInfo: nil, closure: nil)
        )
        expect(subject.isOn).to(beFalse())
    }

    func test_flip_callsActionsBoundToControlEvents() {
        let subject = UISwitch()
        subject.isHidden = false
        subject.isEnabled = true

        let recorder = UIControlEventRecorder()
        recorder.registerAllEvents(for: subject)

        subject.flip()
        expect(recorder.recordedEvents).to(equal([
                .valueChanged,
                .touchUpInside,
                .allTouchEvents
        ]))
    }
}
