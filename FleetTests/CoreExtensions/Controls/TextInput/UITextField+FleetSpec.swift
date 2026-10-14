import XCTest
import Nimble
import Fleet

@MainActor
class UITextField_FleetSpec: XCTestCase {
    var subject: UITextField!
    var delegate: TestTextFieldDelegate!
    var recorder: UIControlEventRecorder!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        let tuple = createCompleteTextFieldAndDelegate()
        subject = tuple.textField
        delegate = tuple.delegate
        recorder = UIControlEventRecorder()
        recorder.registerAllEvents(for: subject)
        try! Test.embedViewIntoMainApplicationWindow(subject)
    }

    override func tearDown() async throws {
        subject.removeFromSuperview()
        try await super.tearDown()
    }

    func createCompleteTextFieldAndDelegate() -> (textField: UITextField, delegate: TestTextFieldDelegate) {
        let textField = UITextField(frame: CGRect(x: 100,y: 100,width: 100,height: 100))
        let delegate = TestTextFieldDelegate()
        textField.delegate = delegate

        textField.isHidden = false
        textField.isEnabled = true

        return (textField, delegate)
    }

    func test_startEditing_whenTextFieldIsFullyAvailable_putsFocusIntoTheTextField() {
        subject.startEditing()

        expect(self.subject.isFirstResponder).to(beTrue())
    }

    func test_startEditing_whenTextFieldIsFullyAvailable_sendsControlEventsAppropriately() {
        subject.startEditing()

        expect(self.subject.isFirstResponder).to(beTrue())
        expect(self.recorder.recordedEvents).to(equal([
            .touchDown,
            .allTouchEvents,
            .editingDidBegin,
            .allEditingEvents
        ]))
    }

    func test_startEditing_postsToNotificationCenter() {
        let notificationListener = NotificationListener()
        NotificationCenter.default.addObserver(
            notificationListener,
            selector: #selector(NotificationListener.listenTo(notification:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            notificationListener,
            selector: #selector(NotificationListener.listenTo(notification:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )

        subject.startEditing()

        let expectedNotifications = [
            UIResponder.keyboardWillShowNotification,
            UIResponder.keyboardDidShowNotification
        ]

        expect(notificationListener.notificationsReceived).toEventually(contain(expectedNotifications))
    }

    func test_startEditing_whenTextFieldFailsToBecomeFirstResponder_raisesException() {
        // If the text field is not in the window, it will never succeed to become first responder.
        let textFieldNotInWindow = UITextField(frame: CGRect(x: 100,y: 100,width: 100,height: 100))

        textFieldNotInWindow.isHidden = false
        textFieldNotInWindow.isEnabled = true

        expect { textFieldNotInWindow.startEditing() }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "Could not edit UITextField: Text field failed to become first responder. This can happen if the field is not part of the window's hierarchy.", userInfo: nil, closure: nil)
        )
        expect(textFieldNotInWindow.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenTextFieldIsHidden_raisesException() {
        subject.isHidden = true

        expect { self.subject.startEditing() }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "UITextField unavailable for editing: Text field is not visible.", userInfo: nil, closure: nil)
        )
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenTextFieldIsNotEnabled_raisesException() {
        subject.isEnabled = false

        expect { self.subject.startEditing() }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "UITextField unavailable for editing: Text field is not enabled.", userInfo: nil, closure: nil)
        )
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenDelegateAllowsEditing_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowBeginEditing = true

        subject.startEditing()

        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beTrue())
    }

    func test_startEditing_whenDelegateDoesNotAllowEditing_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowBeginEditing = false

        subject.startEditing()

        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beFalse())
        expect(self.delegate.didCallShouldClear).to(beFalse())
    }

    func test_startEditing_whenDelegateDoesNotAllowEditing_stillSendsTouchDownControlEvent() {
        delegate.shouldAllowBeginEditing = false

        subject.startEditing()

        expect(self.recorder.recordedEvents).to(equal([
            .touchDown,
            .allTouchEvents
        ]))
    }

    func test_startEditing_whenAnotherTextFieldWasSelected_whenDelegateAllowsEditing_callsDelegateMethodsAppropriately() {
        let tuple = createCompleteTextFieldAndDelegate()
        let otherTextField = tuple.textField
        let otherDelegate = tuple.delegate
        try! Test.embedViewIntoMainApplicationWindow(otherTextField)

        otherDelegate.shouldAllowBeginEditing = true
        delegate.shouldAllowBeginEditing = true

        otherTextField.startEditing()
        subject.startEditing()

        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beTrue())
        expect(otherDelegate.didCallShouldEndEditing).to(beTrue())
        expect(otherDelegate.didCallDidEndEditing).to(beTrue())
    }

    func test_startEditing_whenAnotherTextFieldWasSelected_whenDelegateAllowsEditing_sendsAllControlEvents() {
        let tuple = createCompleteTextFieldAndDelegate()
        let otherTextField = tuple.textField
        let otherDelegate = tuple.delegate
        try! Test.embedViewIntoMainApplicationWindow(otherTextField)

        otherDelegate.shouldAllowBeginEditing = true
        delegate.shouldAllowBeginEditing = true

        otherTextField.startEditing()
        subject.startEditing()

        expect(self.recorder.recordedEvents).to(equal([
            .touchDown,
            .allTouchEvents,
            .editingDidBegin,
            .allEditingEvents
        ]))
    }

    func test_startEditing_whenAnotherTextFieldWasSelected_whenDelegateDoesNotAllowEditing_callsDelegateMethodsAppropriately() {
        let tuple = createCompleteTextFieldAndDelegate()
        let otherTextField = tuple.textField
        let otherDelegate = tuple.delegate
        try! Test.embedViewIntoMainApplicationWindow(otherTextField)

        otherDelegate.shouldAllowBeginEditing = true
        delegate.shouldAllowBeginEditing = false

        otherTextField.startEditing()
        subject.startEditing()

        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beFalse())
        expect(otherDelegate.didCallShouldEndEditing).to(beFalse())
        expect(otherDelegate.didCallDidEndEditing).to(beFalse())
    }

    func test_startEditing_whenAlreadyFirstResponder_doesNothing() {
        delegate.shouldAllowBeginEditing = true

        subject.startEditing()
        delegate.resetState()
        subject.startEditing()

        expect(self.delegate.didCallShouldBeginEditing).to(beFalse())
    }

    func test_stopEditing_whenTextFieldIsFullyAvailable_removesFocusFromTheTextField() {
        subject.startEditing()
        subject.stopEditing()

        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_stopEditing_whenTextFieldIsFullyAvailable_sendsControlEvents() {
        subject.startEditing()
        recorder.erase()
        subject.stopEditing()

        expect(self.recorder.recordedEvents).to(equal([
            .editingDidEnd,
            .allEditingEvents
        ]))
    }

    func test_stopEditing_whenNotFirstResponder_raisesException() {
        expect { self.subject.stopEditing() }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "Could not edit UITextField: Must start editing the text field before you can stop editing it.", userInfo: nil, closure: nil)
        )
    }

    func test_stopEditing_whenDelegateAllowsEditingToEnd_callsDelegateMethodsAppropriately() {
        subject.startEditing()
        delegate.resetState()
        delegate.shouldAllowEndEditing = true

        subject.stopEditing()

        expect(self.delegate.didCallShouldEndEditing).to(beTrue())
        expect(self.delegate.didCallDidEndEditing).to(beTrue())
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_stopEditing_postsToNotificationCenter() {
        let notificationListener = NotificationListener()
        NotificationCenter.default.addObserver(
            notificationListener,
            selector: #selector(NotificationListener.listenTo(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            notificationListener,
            selector: #selector(NotificationListener.listenTo(notification:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )

        subject.startEditing()
        subject.stopEditing()

        let expectedNotifications = [
            UIResponder.keyboardWillHideNotification,
            UIResponder.keyboardDidHideNotification
        ]

        expect(notificationListener.notificationsReceived).toEventually(contain(expectedNotifications))
    }

    func test_type_typesGivenTextIntoTextField() {
        subject.startEditing()
        subject.type(text: "turtle magic")

        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_type_sendsControlEvents() {
        subject.startEditing()
        recorder.erase()
        subject.type(text: "four")

        // One `.editingChanged` event for each letter typed.
        expect(self.recorder.recordedEvents).to(equal([
            .editingChanged,
            .allEditingEvents,
            .editingChanged,
            .allEditingEvents,
            .editingChanged,
            .allEditingEvents,
            .editingChanged,
            .allEditingEvents
        ]))
    }

    func test_type_whenNotFirstResponder_raisesException() {
        expect { self.subject.type(text: "turtle magic") }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "Could not edit UITextField: Must start editing the text field before text can be typed into it.", userInfo: nil, closure: nil)
        )
    }

    func test_type_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowChangeText = true
        subject.startEditing()
        subject.type(text: "turtle magic")

        expect(self.delegate.textChanges).to(equal(["t", "u", "r", "t", "l", "e", " ", "m", "a", "g", "i", "c"]))
        expect(self.delegate.textRanges.count).to(equal(12))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.textRanges[9].location).to(equal(9))
        expect(self.delegate.textRanges[9].length).to(equal(0))
    }

    func test_type_whenDelegateDoesNotAllowTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowChangeText = false
        subject.startEditing()
        subject.type(text: "turtle magic")

        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(12))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.textRanges[9].location).to(equal(0))
        expect(self.delegate.textRanges[9].length).to(equal(0))
        expect(self.subject.text).to(equal(""))
    }

    func test_type_whenDelegateDoesNotAllowTextChanges_sendsNoEvents() {
        delegate.shouldAllowChangeText = false
        subject.startEditing()
        recorder.erase()
        subject.type(text: "turtle magic")

        expect(self.recorder.recordedEvents).to(equal([]))
    }

    func test_type_whenNoDelegate_typesGivenTextIntoTextField() {
        subject.startEditing()
        subject.delegate = nil
        subject.type(text: "turtle magic")

        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_type_whenNoDelegate_sendsControlEvents() {
        subject.startEditing()
        subject.delegate = nil
        recorder.erase()
        subject.type(text: "four")

        // One `.editingChanged` event for each letter typed.
        expect(self.recorder.recordedEvents).to(equal([
            .editingChanged,
            .allEditingEvents,
            .editingChanged,
            .allEditingEvents,
            .editingChanged,
            .allEditingEvents,
            .editingChanged,
            .allEditingEvents
        ]))
    }

    func test_paste_putsGivenTextIntoTextField() {
        subject.startEditing()
        subject.paste(text: "turtle magic")

        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_paste_sendsControlEvents() {
        subject.startEditing()
        recorder.erase()
        subject.paste(text: "turtle magic")

        expect(self.recorder.recordedEvents).to(equal([
            .editingChanged,
            .allEditingEvents
        ]))
    }

    func test_paste_whenNotFirstResponder_raisesException() {
        expect { self.subject.paste(text: "turtle magic") }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "Could not edit UITextField: Must start editing the text field before text can be pasted into it.", userInfo: nil, closure: nil)
        )
    }

    func test_paste_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowChangeText = true
        subject.startEditing()
        subject.paste(text: "turtle magic")

        expect(self.delegate.textChanges).to(equal(["turtle magic"]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
    }

    func test_paste_whenDelegateDoesNotAllowTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowChangeText = false
        subject.startEditing()
        subject.paste(text: "turtle magic")

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
    }

    func test_paste_whenDelegateDoesNotAllowTextChanges_sendsNoEvents() {
        delegate.shouldAllowChangeText = false
        subject.startEditing()
        recorder.erase()
        subject.paste(text: "turtle magic")

        expect(self.recorder.recordedEvents).to(equal([]))
    }

    func test_paste_whenNoDelegate_sendsControlEvents() {
        subject.startEditing()
        subject.delegate = nil
        recorder.erase()
        subject.paste(text: "turtle magic")

        // One `.editingChanged` event for each letter typed.
        expect(self.recorder.recordedEvents).to(equal([
            .editingChanged,
            .allEditingEvents
        ]))
    }

    func test_backspace_deletesTheLastCharacter() {
        subject.startEditing()
        subject.type(text: "turtle magic")
        delegate.resetState()

        subject.backspace()

        expect(self.subject.text).to(equal("turtle magi"))
    }

    func test_backspace_sendsControlEvents() {
        subject.startEditing()
        subject.type(text: "turtle magic")
        delegate.resetState()
        recorder.erase()

        subject.backspace()

        expect(self.recorder.recordedEvents).to(equal([
            .editingChanged,
            .allEditingEvents
        ]))
    }

    func test_backspace_whenNotFirstResponder_raisesException() {
        expect { self.subject.backspace() }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "Could not edit UITextField: Must start editing the text field before backspaces can be performed.", userInfo: nil, closure: nil)
        )
    }

    func test_backspace_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowChangeText = true
        subject.startEditing()
        subject.type(text: "turtle magic")

        delegate.resetState()

        subject.backspace()

        expect(self.delegate.textChanges).to(equal([""]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(11))
        expect(self.delegate.textRanges[0].length).to(equal(1))
    }

    func test_backspace_whenDelegateDoesNotAllowTextChanges_callsDelegateMethodsAppropriately() {
        subject.startEditing()
        subject.type(text: "turtle magic")

        delegate.resetState()

        delegate.shouldAllowChangeText = false
        subject.backspace()

        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(11))
        expect(self.delegate.textRanges[0].length).to(equal(1))
        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_backspace_whenNoDelegate_deletesTheLastCharacter() {
        subject.startEditing()
        subject.type(text: "turtle magic")

        subject.delegate = nil

        subject.backspace()

        expect(self.subject.text).to(equal("turtle magi"))
    }

    func test_backspace_whenNoDelegate_sendsControlEvents() {
        subject.startEditing()
        subject.type(text: "turtle magic")
        recorder.erase()

        subject.delegate = nil

        subject.backspace()

        expect(self.recorder.recordedEvents).to(equal([
            .editingChanged,
            .allEditingEvents
        ]))
    }

    func test_backspace_whenNoTextInTextField_doesNothing() {
        subject.startEditing()

        delegate.resetState()

        subject.backspace()

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textChanges).to(equal([""]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
    }

    func test_backspaceAll_deletesAllTextInTheField() {
        subject.startEditing()
        subject.type(text: "turtle magic")
        delegate.resetState()

        subject.backspaceAll()

        expect(self.subject.text).to(equal(""))
    }

    func test_backspaceAll_sendsControlEvents() {
        subject.startEditing()
        subject.type(text: "tur")
        delegate.resetState()
        recorder.erase()

        subject.backspaceAll()

        expect(self.recorder.recordedEvents).to(equal([
            .editingChanged,
            .allEditingEvents,
            .editingChanged,
            .allEditingEvents,
            .editingChanged,
            .allEditingEvents
            ]))
    }

    func test_backspaceAll_whenNotFirstResponder_raisesException() {
        expect { self.subject.backspaceAll() }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "Could not edit UITextField: Must start editing the text field before backspaces can be performed.", userInfo: nil, closure: nil)
        )
    }

    func test_backspaceAll_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowChangeText = true
        subject.startEditing()
        subject.type(text: "turtle")

        delegate.resetState()

        subject.backspaceAll()

        expect(self.delegate.textChanges).to(equal(["","","","","",""]))
        expect(self.delegate.textRanges.count).to(equal(6))
        expect(self.delegate.textRanges[0].location).to(equal(5))
        expect(self.delegate.textRanges[0].length).to(equal(1))
    }

    func test_backspaceAll_whenDelegateDoesNotAllowTextChanges_callsDelegateMethodsAppropriately() {
        subject.startEditing()
        subject.type(text: "turtle magic")

        delegate.resetState()

        delegate.shouldAllowChangeText = false
        subject.backspaceAll()

        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(12))
        expect(self.delegate.textRanges[0].location).to(equal(11))
        expect(self.delegate.textRanges[0].length).to(equal(1))
        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_backspaceAll_whenNoDelegate_deletesEveryCharacter() {
        subject.startEditing()
        subject.type(text: "turtle magic")

        subject.delegate = nil

        subject.backspaceAll()

        expect(self.subject.text).to(equal(""))
    }

    func test_backspaceAll_whenNoDelegate_sendsControlEvents() {
        subject.startEditing()
        subject.type(text: "tur")
        recorder.erase()

        subject.delegate = nil

        subject.backspaceAll()

        expect(self.recorder.recordedEvents).to(equal([
            .editingChanged,
            .allEditingEvents,
            .editingChanged,
            .allEditingEvents,
            .editingChanged,
            .allEditingEvents
            ]))
    }

    func test_backspaceAll_whenNoTextInTextField_doesNothing() {
        subject.startEditing()

        delegate.resetState()

        subject.backspaceAll()

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(0))
    }

    func test_clearText_whenTextFieldDisplaysClearButtonAlways_clearsTextWhetherEditingFieldOrNot() {
        subject.clearButtonMode = .always
        subject.enter(text: "turtle magic")

        subject.clearText() // Without trying to edit first

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.didCallShouldClear).to(beTrue())

        delegate.resetState()

        subject.startEditing()
        subject.type(text: "turtle magic")
        subject.clearText() // While in edit mode

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.didCallShouldClear).to(beTrue())
    }

    func test_clearText_whenTextFieldDisplaysClearButtonNever_raisesException() {
        subject.clearButtonMode = .never
        subject.enter(text: "turtle magic")

        // Without trying to edit first
        expect { self.subject.clearText() }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "Could not clear text from UITextField: Clear button is never displayed.", userInfo: nil, closure: nil)
        )

        expect(self.subject.text).to(equal("turtle magic"))
        expect(self.delegate.didCallShouldClear).to(beFalse())

        delegate.resetState()

        subject.startEditing()
        subject.type(text: "++")

        // While in edit mode
        expect { self.subject.clearText() }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "Could not clear text from UITextField: Clear button is never displayed.", userInfo: nil, closure: nil)
        )

        expect(self.subject.text).to(equal("turtle magic++"))
        expect(self.delegate.didCallShouldClear).to(beFalse())
    }

    func test_clearText_whenTextFieldDisplaysClearButtonOnlyDuringEditing() {
        subject.clearButtonMode = .whileEditing
        subject.enter(text: "turtle magic")

        // Without trying to edit first
        expect { self.subject.clearText() }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "Could not clear text from UITextField: Clear button is hidden when not editing.", userInfo: nil, closure: nil)
        )

        expect(self.subject.text).to(equal("turtle magic"))
        expect(self.delegate.didCallShouldClear).to(beFalse())

        delegate.resetState()

        subject.startEditing()
        subject.type(text: "++")

        // While in edit mode
        subject.clearText()

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.didCallShouldClear).to(beTrue())
    }

    func test_clearText_whenTextFieldDisplaysClearButtonUnlessEditing() {
        subject.clearButtonMode = .unlessEditing
        subject.enter(text: "turtle magic")

        // Without trying to edit first
        subject.clearText()

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.didCallShouldClear).to(beTrue())

        delegate.resetState()

        subject.startEditing()
        subject.type(text: "++")

        // While in edit mode
        expect { self.subject.clearText() }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "Could not clear text from UITextField: Clear button is hidden when editing.", userInfo: nil, closure: nil)
        )

        expect(self.subject.text).to(equal("++"))
        expect(self.delegate.didCallShouldClear).to(beFalse())
    }

    func test_clearText_whenTextFieldIsHidden_raisesException() {
        subject.isHidden = true
        subject.clearButtonMode = .always

        expect { self.subject.clearText() }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "UITextField unavailable for editing: Text field is not visible.", userInfo: nil, closure: nil)
        )
        expect(self.delegate.didCallShouldClear).to(beFalse())
    }

    func test_clearText_whenTextFieldIsNotEnabled_raisesException() {
        subject.isEnabled = false
        subject.clearButtonMode = .always

        expect { self.subject.clearText() }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "UITextField unavailable for editing: Text field is not enabled.", userInfo: nil, closure: nil)
        )
        expect(self.delegate.didCallShouldClear).to(beFalse())
    }

    func test_clearText_whenItWorks_sendsControlEvents() {
        subject.clearButtonMode = .always
        subject.enter(text: "turtle magic")
        recorder.erase()
        subject.clearText()

        expect(self.recorder.recordedEvents).to(equal([
            .editingChanged,
            .allEditingEvents
        ]))
    }

    func test_clearText_whenDelegateDoesNotAllowClearing_doesNotClear() {
        subject.clearButtonMode = .always
        subject.enter(text: "turtle magic")
        delegate.shouldAllowClearText = false
        recorder.erase()
        subject.clearText()

        expect(self.subject.text).to(equal("turtle magic"))
        expect(self.delegate.didCallShouldClear).to(beTrue())
        expect(self.recorder.recordedEvents).to(equal([]))
    }

    func test_enter_convenienceMethod_startsEditingATextFieldTypesTextAndStopsEditingAllInOneAction() {
        subject.enter(text: "turtle magic")

        expect(self.subject.text).to(equal("turtle magic"))
        expect(self.delegate.textChanges).to(equal(["t", "u", "r", "t", "l", "e", " ", "m", "a", "g", "i", "c"]))
        expect(self.delegate.textRanges.count).to(equal(12))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.textRanges[9].location).to(equal(9))
        expect(self.delegate.textRanges[9].length).to(equal(0))
        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beTrue())
        expect(self.delegate.didCallShouldEndEditing).to(beTrue())
        expect(self.delegate.didCallDidEndEditing).to(beTrue())
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_enter_convenienceMethod_sendsControlEvents() {
        subject.enter(text: "four")

        expect(self.recorder.recordedEvents).to(equal([
            .touchDown,
            .allTouchEvents,
            .editingDidBegin,
            .allEditingEvents,
            .editingChanged,
            .allEditingEvents,
            .editingChanged,
            .allEditingEvents,
            .editingChanged,
            .allEditingEvents,
            .editingChanged,
            .allEditingEvents,
            .editingDidEnd,
            .allEditingEvents
        ]))
    }

    func test_whenTextFieldClearsOnEntry_whenDelegateAllowsClearing_clearsTextWhenEditingBegins() {
        subject.clearsOnBeginEditing = true
        delegate.shouldAllowClearText = true
        subject.enter(text: "turtle magic")
        expect(self.subject.text).to(equal("turtle magic"))

        subject.startEditing()
        expect(self.subject.text).to(equal(""))
    }

    func test_whenTextFieldClearsOnEntry_whenDelegateDoesNotAllowClearing_doesNotClearTextWhenEditingBegins() {
        subject.clearsOnBeginEditing = true
        delegate.shouldAllowClearText = false
        subject.enter(text: "turtle magic")
        expect(self.subject.text).to(equal("turtle magic"))

        subject.startEditing()
        expect(self.subject.text).to(equal("turtle magic"))
    }

    fileprivate class BarebonesTextFieldDelegate: NSObject, UITextFieldDelegate {
        override init() {}
    } // implements none of the methods

    func test_whenUsingDelegateWithNoImplementations_performsAsExpected() {
        let textField = UITextField()
        let minimallyImplementedDelegate = BarebonesTextFieldDelegate()
        textField.delegate = minimallyImplementedDelegate
        try! Test.embedViewIntoMainApplicationWindow(textField)

        textField.enter(text: "turtle magic")
        expect(textField.text).to(equal("turtle magic"))
        textField.startEditing()
        textField.backspace()
        expect(textField.text).to(equal("turtle magi"))
        textField.paste(text: "c woo")
        expect(textField.text).to(equal("turtle magic woo"))
        textField.stopEditing()
    }

    func test_whenUserInteractionIsDisabled_doesAbsolutelyNothingAndRaisesException() {
        subject.isUserInteractionEnabled = false
        expect { self.subject.enter(text: "turtle magic") }.to(
            raiseException(named: "Fleet.TextFieldError", reason: "UITextField unavailable for editing: View does not allow user interaction.", userInfo: nil, closure: nil)
        )

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(0))
        expect(self.delegate.didCallShouldBeginEditing).to(beFalse())
        expect(self.delegate.didCallDidBeginEditing).to(beFalse())
        expect(self.delegate.didCallShouldEndEditing).to(beFalse())
        expect(self.delegate.didCallDidEndEditing).to(beFalse())
        expect(self.subject.isFirstResponder).to(beFalse())
    }
}

// MARK: - Unicode, selection, and refusal semantics

extension UITextField_FleetSpec {
    private func select(_ range: NSRange) {
        let start = subject.beginningOfDocument
        let from = subject.position(from: start, offset: range.location)!
        let to = subject.position(from: from, offset: range.length)!
        subject.selectedTextRange = subject.textRange(from: from, to: to)
    }

    private func startEditing(withText text: String, selecting range: NSRange? = nil) {
        subject.startEditing()
        subject.text = text
        select(range ?? NSRange(location: (text as NSString).length, length: 0))
        delegate.resetState()
    }

    func test_startEditing_consultsShouldBeginEditingExactlyOnce() {
        subject.startEditing()

        expect(self.delegate.callLog).to(equal(["textFieldShouldBeginEditing", "textFieldDidBeginEditing"]))
    }

    func test_startEditing_whenDelegateRefuses_returnsFalseAndNeverBecomesFirstResponder() {
        delegate.shouldAllowBeginEditing = false
        let notificationListener = NotificationListener()
        NotificationCenter.default.addObserver(notificationListener, selector: #selector(NotificationListener.listenTo(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(notificationListener, selector: #selector(NotificationListener.listenTo(notification:)), name: UIResponder.keyboardDidShowNotification, object: nil)

        let result = subject.startEditing()

        expect(result).to(beFalse())
        expect(self.subject.isFirstResponder).to(beFalse())
        expect(self.delegate.callLog).to(equal(["textFieldShouldBeginEditing"]))
        expect(notificationListener.notificationsReceived).to(beEmpty())
    }

    func test_startEditing_whenAlreadyFirstResponder_returnsTrue() {
        subject.startEditing()

        expect(self.subject.startEditing()).to(beTrue())
    }

    func test_stopEditing_consultsShouldEndEditingExactlyOnce() {
        subject.startEditing()
        delegate.resetState()

        let result = subject.stopEditing()

        expect(result).to(beTrue())
        expect(self.subject.isFirstResponder).to(beFalse())
        expect(self.delegate.callLog).to(equal(["textFieldShouldEndEditing", "textFieldDidEndEditing"]))
    }

    func test_stopEditing_whenDelegateRefuses_returnsFalseAndKeepsFirstResponder() {
        subject.startEditing()
        delegate.resetState()
        delegate.shouldAllowEndEditing = false
        let notificationListener = NotificationListener()
        NotificationCenter.default.addObserver(notificationListener, selector: #selector(NotificationListener.listenTo(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(notificationListener, selector: #selector(NotificationListener.listenTo(notification:)), name: UIResponder.keyboardDidHideNotification, object: nil)

        let result = subject.stopEditing()

        expect(result).to(beFalse())
        expect(self.subject.isFirstResponder).to(beTrue())
        expect(self.delegate.callLog).to(equal(["textFieldShouldEndEditing"]))
        expect(notificationListener.notificationsReceived).to(beEmpty())
    }

    func test_enter_whenDelegateRefusesToBeginEditing_stopsBeforeChangingText() {
        subject.text = "kept"
        delegate.shouldAllowBeginEditing = false

        let result = subject.enter(text: "new")

        expect(result).to(beFalse())
        expect(self.subject.text).to(equal("kept"))
        expect(self.delegate.callLog).to(equal(["textFieldShouldBeginEditing"]))
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_enter_whenDelegateRefusesToEndEditing_typesTextAndReportsFailure() {
        delegate.shouldAllowEndEditing = false

        let result = subject.enter(text: "ab")

        expect(result).to(beFalse())
        expect(self.subject.text).to(equal("ab"))
        expect(self.subject.isFirstResponder).to(beTrue())
        expect(self.delegate.didCallDidEndEditing).to(beFalse())
    }

    func test_enter_whenEverythingSucceeds_returnsTrue() {
        expect(self.subject.enter(text: "ab")).to(beTrue())
        expect(self.subject.text).to(equal("ab"))
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_type_withEmojiAlreadyInText_reportsUTF16Locations() {
        startEditing(withText: "a😀")

        subject.type(text: "b😀")

        expect(self.subject.text).to(equal("a😀b😀"))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 3, length: 0), NSRange(location: 4, length: 0)]))
        expect(self.delegate.callLog).to(equal(["shouldChange", "shouldChange"]))
    }

    func test_type_withCombiningCharacters_typesEachGraphemeClusterAsOneChange() {
        startEditing(withText: "")

        subject.type(text: "e\u{301}f")

        expect(self.subject.text).to(equal("e\u{301}f"))
        expect(self.delegate.textChanges).to(equal(["e\u{301}", "f"]))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 0, length: 0), NSRange(location: 2, length: 0)]))
    }

    func test_type_atCaretInMiddleOfText_insertsAtCaret() {
        startEditing(withText: "hello", selecting: NSRange(location: 2, length: 0))

        subject.type(text: "Z")

        expect(self.subject.text).to(equal("heZllo"))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 2, length: 0)]))
    }

    func test_type_withSelection_firstCharacterReplacesSelection() {
        startEditing(withText: "hello", selecting: NSRange(location: 1, length: 2))

        subject.type(text: "XY")

        expect(self.subject.text).to(equal("hXYlo"))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 1, length: 2), NSRange(location: 2, length: 0)]))
    }

    func test_type_whenDelegateRefusesChange_leavesSelectionAndTextUntouched() {
        startEditing(withText: "hello", selecting: NSRange(location: 1, length: 2))
        delegate.shouldAllowChangeText = false

        subject.type(text: "X")

        expect(self.subject.text).to(equal("hello"))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 1, length: 2)]))
    }

    func test_type_emptyString_changesNothing() {
        startEditing(withText: "hi")

        subject.type(text: "")

        expect(self.subject.text).to(equal("hi"))
        expect(self.delegate.callLog).to(beEmpty())
    }

    func test_paste_withSelection_replacesSelectionInOneChange() {
        startEditing(withText: "a😀bc", selecting: NSRange(location: 1, length: 2))

        subject.paste(text: "XYZ")

        expect(self.subject.text).to(equal("aXYZbc"))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 1, length: 2)]))
        expect(self.delegate.textChanges).to(equal(["XYZ"]))
    }

    func test_paste_atCaretInMiddleOfText_insertsAtCaretWithUTF16Location() {
        startEditing(withText: "a😀bc", selecting: NSRange(location: 3, length: 0))

        subject.paste(text: "😀")

        expect(self.subject.text).to(equal("a😀😀bc"))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 3, length: 0)]))
    }

    func test_paste_whenDelegateRefuses_leavesTextUnchanged() {
        startEditing(withText: "hello", selecting: NSRange(location: 1, length: 2))
        delegate.shouldAllowChangeText = false

        subject.paste(text: "XYZ")

        expect(self.subject.text).to(equal("hello"))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 1, length: 2)]))
    }

    func test_backspace_afterEmoji_removesWholeEmojiAndReportsItsUTF16Range() {
        startEditing(withText: "a😀")

        subject.backspace()

        expect(self.subject.text).to(equal("a"))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 1, length: 2)]))
    }

    func test_backspace_afterJoinedEmojiSequence_removesWholeSequence() {
        startEditing(withText: "a👨‍👩‍👧")

        subject.backspace()

        expect(self.subject.text).to(equal("a"))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 1, length: 8)]))
    }

    func test_backspace_afterCombiningCharacter_removesWholeComposedSequence() {
        startEditing(withText: "ae\u{301}")

        subject.backspace()

        expect(self.subject.text).to(equal("a"))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 1, length: 2)]))
    }

    func test_backspace_withSelection_deletesSelectionOnly() {
        startEditing(withText: "hello", selecting: NSRange(location: 1, length: 2))

        subject.backspace()

        expect(self.subject.text).to(equal("hlo"))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 1, length: 2)]))
    }

    func test_backspace_atCaretInMiddleOfText_deletesCharacterBeforeCaret() {
        startEditing(withText: "hello", selecting: NSRange(location: 3, length: 0))

        subject.backspace()

        expect(self.subject.text).to(equal("helo"))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 2, length: 1)]))
    }

    func test_backspace_atStartOfNonEmptyText_changesNothing() {
        startEditing(withText: "hello", selecting: NSRange(location: 0, length: 0))

        subject.backspace()

        expect(self.subject.text).to(equal("hello"))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 0, length: 0)]))
    }

    func test_backspace_whenDelegateRefuses_leavesComposedCharacterInPlace() {
        startEditing(withText: "a😀")
        delegate.shouldAllowChangeText = false

        subject.backspace()

        expect(self.subject.text).to(equal("a😀"))
        expect(self.delegate.textRanges).to(equal([NSRange(location: 1, length: 2)]))
    }

    func test_backspaceAll_withMixedUnicode_deletesEveryCharacterWithUTF16Ranges() {
        startEditing(withText: "a😀e\u{301}")

        subject.backspaceAll()

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textRanges).to(equal([
            NSRange(location: 3, length: 2),
            NSRange(location: 1, length: 2),
            NSRange(location: 0, length: 1)
        ]))
    }

    func test_backspaceAll_withSelectionInMiddle_deletesAllText() {
        startEditing(withText: "hello", selecting: NSRange(location: 1, length: 2))

        subject.backspaceAll()

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textRanges.count).to(equal(5))
    }

    func test_throwingForms_whenNotFirstResponder_throwInvalidSetupInsteadOfRaising() {
        for call in [
            { _ = try self.subject.stopEditingOrThrow() },
            { _ = try self.subject.typeOrThrow(text: "a") },
            { _ = try self.subject.pasteOrThrow(text: "a") },
            { _ = try self.subject.backspaceOrThrow() },
            { _ = try self.subject.backspaceAllOrThrow() },
        ] as [() throws -> Void] {
            XCTAssertThrowsError(try call()) { error in
                XCTAssertEqual((error as? FleetFailure)?.kind, .invalidSetup)
                XCTAssertEqual((error as? FleetFailure)?.target, "UITextField")
            }
        }
    }

    func test_startEditingOrThrow_whenHidden_throwsUnavailableInteraction() {
        subject.isHidden = true
        XCTAssertThrowsError(try subject.startEditingOrThrow()) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .unavailableInteraction)
        }
        XCTAssertFalse(subject.isFirstResponder)
    }

    func test_startEditingOrThrow_whenNotInWindow_throwsInvalidSetup() {
        subject.removeFromSuperview()
        XCTAssertThrowsError(try subject.startEditingOrThrow()) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .invalidSetup)
        }
    }

    func test_throwingForms_reportPerformedAndEditText() throws {
        XCTAssertEqual(try subject.enterOrThrow(text: "ab"), .performed)
        XCTAssertEqual(subject.text, "ab")
        _ = try subject.startEditingOrThrow()
        XCTAssertEqual(try subject.backspaceAllOrThrow(), .performed)
        XCTAssertEqual(subject.text, "")
        XCTAssertEqual(try subject.pasteOrThrow(text: "xy"), .performed)
        XCTAssertEqual(subject.text, "xy")
    }

    func test_startEditingOrThrow_whenDelegateRefuses_returnsRefusalNotError() throws {
        delegate.shouldAllowBeginEditing = false
        let outcome = try subject.startEditingOrThrow()
        XCTAssertEqual(outcome, .refusedByDelegate(method: "textFieldShouldBeginEditing(_:)"))
        XCTAssertFalse(subject.isFirstResponder)
    }

    func test_startEditingOrThrow_whenCannotBecomeFirstResponder_throwsUnavailableInsteadOfRefusal() {
        let unfocusable = UnfocusableTextField()
        subject.superview!.addSubview(unfocusable)
        defer { unfocusable.removeFromSuperview() }
        XCTAssertNil(unfocusable.delegate); XCTAssertFalse(unfocusable.canBecomeFirstResponder)
        XCTAssertThrowsError(try unfocusable.startEditingOrThrow()) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .unavailableInteraction)
            XCTAssertEqual((error as? FleetFailure)?.target, "UITextField")
        }
        XCTAssertFalse(unfocusable.isFirstResponder)
    }

    func test_startEditingOrThrow_whenCannotBecomeFirstResponderWithAcceptingDelegate_throwsUnavailableInsteadOfRefusal() {
        let unfocusable = UnfocusableTextField()
        subject.superview!.addSubview(unfocusable)
        defer { unfocusable.removeFromSuperview() }
        delegate.shouldAllowBeginEditing = true
        unfocusable.delegate = delegate
        XCTAssertFalse(unfocusable.canBecomeFirstResponder)
        XCTAssertThrowsError(try unfocusable.startEditingOrThrow()) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .unavailableInteraction)
        }
        XCTAssertFalse(unfocusable.isFirstResponder)
        XCTAssertTrue(unfocusable.delegate === delegate)
    }

    func test_startEditingOrThrow_preservesDelegateRemovedByDidBeginEditing() throws {
        let removing = DelegateRemovingOnBegin()
        subject.delegate = removing
        _ = try subject.startEditingOrThrow()
        XCTAssertTrue(subject.isFirstResponder)
        XCTAssertNil(subject.delegate)
    }
}

@MainActor
private final class DelegateRemovingOnBegin: NSObject, UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) { textField.delegate = nil }
}

private final class UnfocusableTextField: UITextField {
    override var canBecomeFirstResponder: Bool { false }
}
