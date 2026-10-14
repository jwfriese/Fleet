import XCTest
import Nimble
import Fleet

@MainActor
class UITextView_FleetSpec: XCTestCase {
    var subject: UITextView!
    var delegate: TestTextViewDelegate!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        let tuple = createCompleteTextViewAndDelegate()
        subject = tuple.textView
        delegate = tuple.delegate
        try! Test.embedViewIntoMainApplicationWindow(subject)
    }

    override func tearDown() async throws {
        subject.removeFromSuperview()
        try await super.tearDown()
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

// MARK: - Unicode, selection, and refusal semantics

extension UITextView_FleetSpec {
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

        expect(self.delegate.callLog).to(equal(["textViewShouldBeginEditing", "textViewDidBeginEditing"]))
    }

    func test_startEditing_whenDelegateRefuses_returnsFalseAndNeverBecomesFirstResponder() {
        delegate.shouldAllowBeginEditing = false
        let notificationListener = NotificationListener()
        NotificationCenter.default.addObserver(notificationListener, selector: #selector(NotificationListener.listenTo(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(notificationListener, selector: #selector(NotificationListener.listenTo(notification:)), name: UIResponder.keyboardDidShowNotification, object: nil)

        let result = subject.startEditing()

        expect(result).to(beFalse())
        expect(self.subject.isFirstResponder).to(beFalse())
        expect(self.delegate.callLog).to(equal(["textViewShouldBeginEditing"]))
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
        expect(self.delegate.callLog).to(equal(["textViewShouldEndEditing", "textViewDidEndEditing"]))
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
        expect(self.delegate.callLog).to(equal(["textViewShouldEndEditing"]))
        expect(notificationListener.notificationsReceived).to(beEmpty())
    }

    func test_enter_whenDelegateRefusesToBeginEditing_stopsBeforeChangingText() {
        subject.text = "kept"
        delegate.shouldAllowBeginEditing = false

        let result = subject.enter(text: "new")

        expect(result).to(beFalse())
        expect(self.subject.text).to(equal("kept"))
        expect(self.delegate.callLog).to(equal(["textViewShouldBeginEditing"]))
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
        delegate.shouldAllowTextChanges = false

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
        delegate.shouldAllowTextChanges = false

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
        delegate.shouldAllowTextChanges = false

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
                XCTAssertEqual((error as? FleetFailure)?.target, "UITextView")
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
        XCTAssertEqual(outcome, .refusedByDelegate(method: "textViewShouldBeginEditing(_:)"))
        XCTAssertFalse(subject.isFirstResponder)
    }

    func test_startEditingOrThrow_whenCannotBecomeFirstResponder_throwsUnavailableInsteadOfRefusal() {
        let unfocusable = UnfocusableTextView()
        subject.superview!.addSubview(unfocusable)
        defer { unfocusable.removeFromSuperview() }
        XCTAssertNil(unfocusable.delegate); XCTAssertFalse(unfocusable.canBecomeFirstResponder)
        XCTAssertThrowsError(try unfocusable.startEditingOrThrow()) { error in
            XCTAssertEqual((error as? FleetFailure)?.kind, .unavailableInteraction)
            XCTAssertEqual((error as? FleetFailure)?.target, "UITextView")
        }
        XCTAssertFalse(unfocusable.isFirstResponder)
    }
}

private final class UnfocusableTextView: UITextView {
    override var canBecomeFirstResponder: Bool { false }
}
