import XCTest
import Nimble
import Fleet

class UITextView_FleetSpec: XCTestCase {
    var subject: UITextView!
    var delegate: TestTextViewDelegate!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        let tuple = createCompleteTextViewAndDelegate()
        subject = tuple.textView
        delegate = tuple.delegate
        try! Test.embedViewIntoMainApplicationWindow(subject)
    }

    override func tearDown() {
        subject.removeFromSuperview()
        super.tearDown()
    }

    func createCompleteTextViewAndDelegate() -> (textView: UITextView, delegate: TestTextViewDelegate) {
        let textView = UITextView(frame: CGRect(x: 100,y: 100,width: 100,height: 100))
        let delegate = TestTextViewDelegate()
        textView.delegate = delegate

        textView.isHidden = false
        textView.isEditable = true
        textView.isSelectable = true

        return (textView, delegate)
    }

    func test_startEditing_whenTextViewIsFullyAvailable_putsFocusIntoTheTextView() {
        subject.startEditing()

        expect(self.subject.isFirstResponder).to(beTrue())
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

    func test_startEditing_whenTextViewFailsToBecomeFirstResponder_raisesException() {
        // If the text view is not in the window, it will never succeed to become first responder.
        let textViewNotInWindow = UITextView(frame: CGRect(x: 100,y: 100,width: 100,height: 100))

        textViewNotInWindow.isHidden = false
        textViewNotInWindow.isSelectable = true

        expect { textViewNotInWindow.startEditing() }.to(
            raiseException(named: "Fleet.TextViewError", reason: "Could not edit UITextView: Text view failed to become first responder. This can happen if the view is not part of the window's hierarchy.", userInfo: nil, closure: nil)
        )

        expect(textViewNotInWindow.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenTextViewIsHidden_raisesException() {
        subject.isHidden = true

        expect { self.subject.startEditing() }.to(
            raiseException(named: "Fleet.TextViewError", reason: "UITextView unavailable for editing: Text view is not visible.", userInfo: nil, closure: nil)
        )
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenTextViewIsNotSelectable_raisesException() {
        subject.isSelectable = false

        expect { self.subject.startEditing() }.to(
            raiseException(named: "Fleet.TextViewError", reason: "UITextView unavailable for editing: Text view is not selectable.", userInfo: nil, closure: nil)
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
    }

    func test_startEditing_whenTextViewIsNotEditable_raisesException() {
        subject.isEditable = false

        expect { self.subject.startEditing() }.to(
            raiseException(named: "Fleet.TextViewError", reason: "UITextView unavailable for editing: Text view is not editable.", userInfo: nil, closure: nil)
        )
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenAnotherTextViewWasSelected_whenDelegateAllowsEditing_callsDelegateMethodsAppropriately() {
        let tuple = createCompleteTextViewAndDelegate()
        let otherTextView = tuple.textView
        let otherDelegate = tuple.delegate
        try! Test.embedViewIntoMainApplicationWindow(otherTextView)

        otherDelegate.shouldAllowBeginEditing = true
        delegate.shouldAllowBeginEditing = true

        otherTextView.startEditing()
        subject.startEditing()

        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beTrue())
        expect(otherDelegate.didCallShouldEndEditing).to(beTrue())
        expect(otherDelegate.didCallDidEndEditing).to(beTrue())
    }

    func test_startEditing_whenAnotherTextViewWasSelected_whenDelegateDoesNotAllowEditing_callsDelegateMethodsAppropriately() {
        let tuple = createCompleteTextViewAndDelegate()
        let otherTextView = tuple.textView
        let otherDelegate = tuple.delegate
        try! Test.embedViewIntoMainApplicationWindow(otherTextView)

        otherDelegate.shouldAllowBeginEditing = true
        delegate.shouldAllowBeginEditing = false

        otherTextView.startEditing()
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

    func test_stopEditing_whenTextViewIsFullyAvailable_removesFocusFromTheTextView() {
        subject.startEditing()
        subject.stopEditing()

        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_stopEditing_whenNotFirstResponder_raisesException() {
        expect { self.subject.stopEditing() }.to(
            raiseException(named: "Fleet.TextViewError", reason: "Could not edit UITextView: Must start editing the text view before you can stop editing it.", userInfo: nil, closure: nil)
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

    func test_type_typesGivenTextIntoTextView() {
        subject.startEditing()
        subject.type(text: "turtle magic")

        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_type_whenNotFirstResponder_raisesException() {
        expect { self.subject.type(text: "turtle magic") }.to(
            raiseException(named: "Fleet.TextViewError", reason: "Could not edit UITextView: Must start editing the text view before text can be typed into it.", userInfo: nil, closure: nil)
        )
    }

    func test_type_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = true
        subject.startEditing()
        subject.type(text: "turtle magic")

        expect(self.delegate.textChanges).to(equal(["t", "u", "r", "t", "l", "e", " ", "m", "a", "g", "i", "c"]))
        expect(self.delegate.textRanges.count).to(equal(12))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.textRanges[9].location).to(equal(9))
        expect(self.delegate.textRanges[9].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(12)) // 12 for typed text
        expect(self.delegate.didChangeSelectionCallCount).to(equal(12)) // 12 for typed text
    }

    func test_type_whenDelegateDoesNotAllowTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = false
        subject.startEditing()
        subject.type(text: "turtle magic")

        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(12))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.textRanges[9].location).to(equal(0))
        expect(self.delegate.textRanges[9].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(0))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(0))
        expect(self.subject.text).to(equal(""))
    }

    func test_type_whenNoDelegate_typesGivenTextIntoTextView() {
        subject.startEditing()
        subject.delegate = nil
        subject.type(text: "turtle magic")

        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_paste_putsGivenTextIntoTextView() {
        subject.startEditing()
        subject.paste(text: "turtle magic")

        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_paste_whenNotFirstResponder_raisesException() {
        expect { self.subject.paste(text: "turtle magic") }.to(
            raiseException(named: "Fleet.TextViewError", reason: "Could not edit UITextView: Must start editing the text view before text can be pasted into it.", userInfo: nil, closure: nil)
        )
    }

    func test_paste_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = true
        subject.startEditing()
        subject.paste(text: "turtle magic")

        expect(self.delegate.textChanges).to(equal(["turtle magic"]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(1))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(1))
    }

    func test_paste_whenDelegateDoesNotAllowTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = false
        subject.startEditing()
        subject.paste(text: "turtle magic")

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(0))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(0))
    }

    func test_backspace_deletesTheLastCharacter() {
            subject.startEditing()
            subject.type(text: "turtle magic")

            delegate.resetState()

            subject.backspace()

            expect(self.subject.text).to(equal("turtle magi"))
    }

    func test_backspace_whenNotFirstResponder_raisesException() {
        expect { self.subject.backspace() }.to(
            raiseException(named: "Fleet.TextViewError", reason: "Could not edit UITextView: Must start editing the text view before backspaces can be performed.", userInfo: nil, closure: nil)
        )
    }

    func test_backspace_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = true
        subject.startEditing()
        subject.type(text: "turtle magic")

        delegate.resetState()

        subject.backspace()

        expect(self.delegate.textChanges).to(equal([""]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(11))
        expect(self.delegate.textRanges[0].length).to(equal(1))
        expect(self.delegate.didChangeCallCount).to(equal(1))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(1))
    }

    func test_backspace_whenDelegateDoesNotAllowTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = false
        subject.startEditing()
        subject.type(text: "turtle magic")

        delegate.resetState()

        subject.backspace()

        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(0))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(0))
    }

    func test_backspace_whenNoDelegate_deletesTheLastCharacter() {
        subject.startEditing()
        subject.type(text: "turtle magic")

        subject.delegate = nil

        subject.backspace()

        expect(self.subject.text).to(equal("turtle magi"))
    }

    func test_backspace_whenNoTextInTextView_doesNothing() {
        subject.startEditing()

        delegate.resetState()

        subject.backspace()

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textChanges).to(equal([""]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(0))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(0))
    }

    func test_backspaceAll_deletesAllTextInTheField() {
        subject.startEditing()
        subject.type(text: "turtle magic")
        delegate.resetState()

        subject.backspaceAll()

        expect(self.subject.text).to(equal(""))
    }

    func test_backspaceAll_whenNotFirstResponder_raisesException() {
        expect { self.subject.backspaceAll() }.to(
            raiseException(named: "Fleet.TextViewError", reason: "Could not edit UITextView: Must start editing the text view before backspaces can be performed.", userInfo: nil, closure: nil)
        )
    }

    func test_backspaceAll_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = true
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

        delegate.shouldAllowTextChanges = false
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

    func test_backspaceAll_whenNoTextInTextField_doesNothing() {
        subject.startEditing()

        delegate.resetState()

        subject.backspaceAll()

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(0))
    }

    func test_enter_convenienceMethod_startsEditingATextViewTypesTextAndStopsEditingAllInOneAction() {
        subject.enter(text: "turtle magic")

        expect(self.subject.text).to(equal("turtle magic"))
        expect(self.delegate.textChanges).to(equal(["t", "u", "r", "t", "l", "e", " ", "m", "a", "g", "i", "c"]))
        expect(self.delegate.textRanges.count).to(equal(12))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.textRanges[9].location).to(equal(9))
        expect(self.delegate.textRanges[9].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(12)) // 12 for typed text
        expect(self.delegate.didChangeSelectionCallCount).to(equal(12)) // 12 for typed text
        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beTrue())
        expect(self.delegate.didCallShouldEndEditing).to(beTrue())
        expect(self.delegate.didCallDidEndEditing).to(beTrue())
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    fileprivate class BarebonesTextViewDelegate: NSObject, UITextViewDelegate {
        override init() {}
    } // implements none of the methods

    func test_whenUsingDelegateWithNoImplementations_performsAsExpected() {
        let textView = UITextView()
        let minimallyImplementedDelegate = BarebonesTextViewDelegate()
        textView.delegate = minimallyImplementedDelegate
        try! Test.embedViewIntoMainApplicationWindow(textView)

        textView.enter(text: "turtle magic")
        expect(textView.text).to(equal("turtle magic"))
        textView.startEditing()
        textView.backspace()
        expect(textView.text).to(equal("turtle magi"))
        textView.paste(text: "c woo")
        expect(textView.text).to(equal("turtle magic woo"))
        textView.stopEditing()
    }

    func test_whenUserInteractionIsDisabled_doesAbsolutelyNothingAndThrowsError() {
        subject.isUserInteractionEnabled = false
        expect { self.subject.enter(text: "turtle magic") }.to(
            raiseException(named: "Fleet.TextViewError", reason: "UITextView unavailable for editing: View does not allow user interaction.", userInfo: nil, closure: nil)
        )

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(0))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(0))
        expect(self.delegate.didCallShouldBeginEditing).to(beFalse())
        expect(self.delegate.didCallDidBeginEditing).to(beFalse())
        expect(self.delegate.didCallShouldEndEditing).to(beFalse())
        expect(self.delegate.didCallDidEndEditing).to(beFalse())
        expect(self.subject.isFirstResponder).to(beFalse())
    }
}
