import XCTest
import Fleet
import Nimble

class UIButton_FleetSpec: XCTestCase {
    func test_tap_whenButtonIsVisibleAndEnabled_tapsTheButton() {
        let subject = UIButton()
        subject.isHidden = false
        subject.isEnabled = true

        let recorder = UIControlEventRecorder()
        recorder.registerAllEvents(for: subject)

        try! subject.tap()
        expect(recorder.recordedEvents).to(equal([
            .touchDown,
            .allTouchEvents,
            .touchUpInside,
            .allTouchEvents
        ]))
    }

    func test_tap_whenButtonIsNotVisible_doesNothingAndRaisesException() {
        let subject = UIButton()
        subject.isHidden = true
        subject.isEnabled = true

        let recorder = UIControlEventRecorder()
        recorder.registerAllEvents(for: subject)

        expect { try subject.tap() }.to(
            raiseException(named: "Fleet.ButtonError", reason: "Cannot tap UIButton: Control is not visible.", userInfo: nil, closure: nil)
        )
        expect(recorder.recordedEvents).to(equal([]))
    }

    func test_tap_whenButtonIsNotEnabled_doesNothingAndRaisesException() {
        let subject = UIButton()
        subject.isHidden = false
        subject.isEnabled = false

        let recorder = UIControlEventRecorder()
        recorder.registerAllEvents(for: subject)

        expect { try subject.tap() }.to(
            raiseException(named: "Fleet.ButtonError", reason: "Cannot tap UIButton: Control is not enabled.", userInfo: nil, closure: nil)
        )
        expect(recorder.recordedEvents).to(equal([]))
    }

    func test_tap_whenButtonDoesNotAllowUserInteraction_doesNothingAndRaisesException() {
        let subject = UIButton()
        subject.isHidden = false
        subject.isEnabled = true
        subject.isUserInteractionEnabled = false

        let recorder = UIControlEventRecorder()
        recorder.registerAllEvents(for: subject)

        expect { try subject.tap() }.to(
            raiseException(named: "Fleet.ButtonError", reason: "Cannot tap UIButton: View does not allow user interaction.", userInfo: nil, closure: nil)
        )
        expect(recorder.recordedEvents).to(equal([]))
    }
}
