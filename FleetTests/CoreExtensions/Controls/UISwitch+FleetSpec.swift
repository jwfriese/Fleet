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

    func test_flip_whenUserInteractionIsNotEnabled_doesNotChangeTheSwitchAndRaisesException() {
        let subject = UISwitch()
        subject.isHidden = false
        subject.isEnabled = true
        subject.isUserInteractionEnabled = false
        expect(subject.isOn).to(beFalse())

        expect { try subject.flip() }.to(
            raiseException(named: "Fleet.SwitchError", reason: "Cannot flip UISwitch: View does not allow user interaction.", userInfo: nil, closure: nil)
        )
        expect(subject.isOn).to(beFalse())
    }

    func test_flip_whenSwitchIsNotVisible_doesNotChangeTheSwitchAndRaisesException() {
        let subject = UISwitch()
        subject.isHidden = true
        subject.isEnabled = true
        expect(subject.isOn).to(beFalse())

        expect { try subject.flip() }.to(
            raiseException(named: "Fleet.SwitchError", reason: "Cannot flip UISwitch: Control is not visible.", userInfo: nil, closure: nil)
        )
        expect(subject.isOn).to(beFalse())
    }

    func test_flip_whenSwitchIsNotEnabled_doesNotChangeTheSwitchAndRaisesException() {
        let subject = UISwitch()
        subject.isHidden = false
        subject.isEnabled = false
        expect(subject.isOn).to(beFalse())

        expect { try subject.flip() }.to(
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

        try! subject.flip()
        expect(recorder.recordedEvents).to(equal([
                .valueChanged,
                .touchUpInside,
                .allTouchEvents
        ]))
    }
}
