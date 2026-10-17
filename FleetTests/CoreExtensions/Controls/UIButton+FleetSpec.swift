import XCTest
import Fleet
import Nimble

@MainActor
class UIButton_FleetSpec: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
    }

    func test_tap_whenButtonIsVisibleAndEnabled_tapsTheButton() {
        let subject = UIButton()
        subject.isHidden = false
        subject.isEnabled = true

        let recorder = UIControlEventRecorder()
        recorder.registerAllEvents(for: subject)

        subject.tap()
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

        expect { subject.tap() }.to(
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

        expect { subject.tap() }.to(
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

        expect { subject.tap() }.to(
            raiseException(named: "Fleet.ButtonError", reason: "Cannot tap UIButton: View does not allow user interaction.", userInfo: nil, closure: nil)
        )
        expect(recorder.recordedEvents).to(equal([]))
    }

    // MARK: Modern and retained action registrations

    @objc fileprivate func legacyAction() { legacyCount += 1 }
    private var legacyCount = 0

    func test_tap_invokesPrimaryActionExactlyOnce() {
        var count = 0
        let subject = UIButton(primaryAction: UIAction(title: "Go") { _ in count += 1 })
        subject.tap()
        expect(count).to(equal(1))
    }

    func test_tap_invokesUIActionRegisteredForTouchUpInsideExactlyOnce() {
        var count = 0
        let subject = UIButton()
        subject.addAction(UIAction { _ in count += 1 }, for: .touchUpInside)
        subject.tap()
        expect(count).to(equal(1))
    }

    func test_tap_invokesPrimaryActionTargetActionAndUIActionEachExactlyOnce() {
        var primaryCount = 0
        var modernCount = 0
        let subject = UIButton(primaryAction: UIAction { _ in primaryCount += 1 })
        subject.addAction(UIAction { _ in modernCount += 1 }, for: .touchUpInside)
        subject.addTarget(self, action: #selector(legacyAction), for: .touchUpInside)
        subject.tap()
        expect(primaryCount).to(equal(1))
        expect(modernCount).to(equal(1))
        expect(self.legacyCount).to(equal(1))
    }

    func test_tap_whenPrimaryActionButtonIsDisabled_doesNotInvokeAction() {
        var count = 0
        let subject = UIButton(primaryAction: UIAction { _ in count += 1 })
        subject.isEnabled = false
        expect { subject.tap() }.to(
            raiseException(named: "Fleet.ButtonError", reason: "Cannot tap UIButton: Control is not enabled.", userInfo: nil, closure: nil)
        )
        expect(count).to(equal(0))
    }

    #if os(iOS)
    func test_tap_whenButtonPresentsMenuAsPrimaryAction_raisesExceptionWithoutInvokingActions() {
        var count = 0
        let subject = UIButton()
        subject.menu = UIMenu(children: [UIAction(title: "Item") { _ in count += 1 }])
        subject.showsMenuAsPrimaryAction = true
        subject.addAction(UIAction { _ in count += 1 }, for: .touchUpInside)
        expect { subject.tap() }.to(
            raiseException(named: "Fleet.ButtonError", reason: "Cannot tap UIButton: Control presents a menu as its primary action, which tap() cannot open. Invoke the menu element's handler directly.", userInfo: nil, closure: nil)
        )
        expect(count).to(equal(0))
    }
    #endif
}
