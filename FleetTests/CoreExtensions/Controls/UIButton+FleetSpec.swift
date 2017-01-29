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

    func test_tap_whenButtonIsNotVisible_doesNothingAndThrowsError() {
        let subject = UIButton()
        subject.isHidden = true
        subject.isEnabled = true

        let recorder = UIControlEventRecorder()
        recorder.registerAllEvents(for: subject)

        expect { try subject.tap() }.to(throwError { (error: Fleet.ButtonError) in
            expect(error.description).to(equal("Cannot tap UIButton: Control is not visible."))
        })
        expect(recorder.recordedEvents).to(equal([]))
    }

    func test_tap_whenButtonIsNotEnabled_doesNothingAndThrowsError() {
        let subject = UIButton()
        subject.isHidden = false
        subject.isEnabled = false

        let recorder = UIControlEventRecorder()
        recorder.registerAllEvents(for: subject)

        expect { try subject.tap() }.to(throwError { (error: Fleet.ButtonError) in
            expect(error.description).to(equal("Cannot tap UIButton: Control is not enabled."))
        })
        expect(recorder.recordedEvents).to(equal([]))
    }

    func test_tap_whenButtonDoesNotAllowUserInteraction_doesNothingAndThrowsError() {
        let subject = UIButton()
        subject.isHidden = false
        subject.isEnabled = true
        subject.isUserInteractionEnabled = false

        let recorder = UIControlEventRecorder()
        recorder.registerAllEvents(for: subject)

        expect { try subject.tap() }.to(throwError { (error: Fleet.ButtonError) in
            expect(error.description).to(equal("Cannot tap UIButton: View does not allow user interaction."))
        })
        expect(recorder.recordedEvents).to(equal([]))
    }
}
