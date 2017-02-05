import XCTest
import Nimble
import Fleet

class UITextView_FleetSpec: XCTestCase {
    var subject: UITextView!
    var delegate: TestTextViewDelegate!

    override func setUp() {
        super.setUp()

        let tuple = createCompleteTextViewAndDelegate()
        subject = tuple.textView
        delegate = tuple.delegate
        try! Test.embedViewIntoMainApplicationWindow(subject)
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
        try! subject.startEditing()

        expect(self.subject.isFirstResponder).to(beTrue())
    }

    func test_startEditing_whenTextViewFailsToBecomeFirstResponder_raisesException() {
        // If the text view is not in the window, it will never succeed to become first responder.
        let textViewNotInWindow = UITextView(frame: CGRect(x: 100,y: 100,width: 100,height: 100))

        textViewNotInWindow.isHidden = false
        textViewNotInWindow.isEditable = true
        textViewNotInWindow.isSelectable = true

        expect { try textViewNotInWindow.startEditing() }.to(
            raiseException(named: "Fleet.TextViewError", reason: "Could not edit UITextView: Text view failed to become first responder. This can happen if the view is not part of the window's hierarchy.", userInfo: nil, closure: nil)
        )

        expect(textViewNotInWindow.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenTextViewIsHidden_raisesException() {
        subject.isHidden = true

        expect { try self.subject.startEditing() }.to(
            raiseException(named: "Fleet.TextViewError", reason: "UITextView unavailable for editing: Text view is not visible.", userInfo: nil, closure: nil)
        )
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenTextViewIsNotSelectable_raisesException() {
        subject.isSelectable = false

        expect { try self.subject.startEditing() }.to(
            raiseException(named: "Fleet.TextViewError", reason: "UITextView unavailable for editing: Text view is not selectable.", userInfo: nil, closure: nil)
        )
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenTextViewIsNotEditable_raisesException() {
        subject.isEditable = false

        expect { try self.subject.startEditing() }.to(
            raiseException(named: "Fleet.TextViewError", reason: "UITextView unavailable for editing: Text view is not editable.", userInfo: nil, closure: nil)
        )
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenDelegateAllowsEditing_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowBeginEditing = true
        try! subject.startEditing()

        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beTrue())
    }

    func test_startEditing_whenDelegateDoesNotAllowEditing_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowBeginEditing = false
        try! subject.startEditing()

        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beFalse())
    }

    func test_startEditing_whenAnotherTextViewWasSelected_whenDelegateAllowsEditing_callsDelegateMethodsAppropriately() {
        let tuple = createCompleteTextViewAndDelegate()
        let otherTextView = tuple.textView
        let otherDelegate = tuple.delegate
        try! Test.embedViewIntoMainApplicationWindow(otherTextView)

        otherDelegate.shouldAllowBeginEditing = true
        delegate.shouldAllowBeginEditing = true

        try! otherTextView.startEditing()
        try! subject.startEditing()

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

        try! otherTextView.startEditing()
        try! subject.startEditing()

        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beFalse())
        expect(otherDelegate.didCallShouldEndEditing).to(beFalse())
        expect(otherDelegate.didCallDidEndEditing).to(beFalse())
    }

    func test_startEditing_whenAlreadyFirstResponder_doesNothing() {
        delegate.shouldAllowBeginEditing = true

        try! subject.startEditing()
        delegate.resetState()
        try! subject.startEditing()

        expect(self.delegate.didCallShouldBeginEditing).to(beFalse())
    }

    func test_stopEditing_whenTextViewIsFullyAvailable_removesFocusFromTheTextView() {
        try! subject.startEditing()
        try! subject.stopEditing()

        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_stopEditing_whenNotFirstResponder_raisesException() {
        expect { try self.subject.stopEditing() }.to(
            raiseException(named: "Fleet.TextViewError", reason: "Could not edit UITextView: Must start editing the text view before you can stop editing it.", userInfo: nil, closure: nil)
        )
    }

    func test_stopEditing_whenDelegateAllowsEditingToEnd_callsDelegateMethodsAppropriately() {
        try! subject.startEditing()
        delegate.resetState()
        delegate.shouldAllowEndEditing = true

        try! subject.stopEditing()

        expect(self.delegate.didCallShouldEndEditing).to(beTrue())
        expect(self.delegate.didCallDidEndEditing).to(beTrue())
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_type_typesGivenTextIntoTextView() {
        try! subject.startEditing()
        try! subject.type(text: "turtle magic")

        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_type_whenNotFirstResponder_raisesException() {
        expect { try self.subject.type(text: "turtle magic") }.to(
            raiseException(named: "Fleet.TextViewError", reason: "Could not edit UITextView: Must start editing the text view before text can be typed into it.", userInfo: nil, closure: nil)
        )
    }

    func test_type_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = true
        try! subject.startEditing()
        try! subject.type(text: "turtle magic")

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
        try! subject.startEditing()
        try! subject.type(text: "turtle magic")

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
        try! subject.startEditing()
        subject.delegate = nil
        try! subject.type(text: "turtle magic")

        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_paste_putsGivenTextIntoTextView() {
        try! subject.startEditing()
        try! subject.paste(text: "turtle magic")

        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_paste_whenNotFirstResponder_raisesException() {
        expect { try self.subject.paste(text: "turtle magic") }.to(
            raiseException(named: "Fleet.TextViewError", reason: "Could not edit UITextView: Must start editing the text view before text can be pasted into it.", userInfo: nil, closure: nil)
        )
    }

    func test_paste_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = true
        try! subject.startEditing()
        try! subject.paste(text: "turtle magic")

        expect(self.delegate.textChanges).to(equal(["turtle magic"]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(1))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(1))
    }

    func test_paste_whenDelegateDoesNotAllowTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = false
        try! subject.startEditing()
        try! subject.paste(text: "turtle magic")

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(0))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(0))
    }

    func test_backspace_deletesTheLastCharacter() {
            try! subject.startEditing()
            try! subject.type(text: "turtle magic")

            delegate.resetState()

            try! subject.backspace()

            expect(self.subject.text).to(equal("turtle magi"))
    }

    func test_backspace_whenNotFirstResponder_raisesException() {
        expect { try self.subject.backspace() }.to(
            raiseException(named: "Fleet.TextViewError", reason: "Could not edit UITextView: Must start editing the text view before backspaces can be performed.", userInfo: nil, closure: nil)
        )
    }

    func test_backspace_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = true
        try! subject.startEditing()
        try! subject.type(text: "turtle magic")

        delegate.resetState()

        try! subject.backspace()

        expect(self.delegate.textChanges).to(equal([""]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(11))
        expect(self.delegate.textRanges[0].length).to(equal(1))
        expect(self.delegate.didChangeCallCount).to(equal(1))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(1))
    }

    func test_backspace_whenDelegateDoesNotAllowTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = false
        try! subject.startEditing()
        try! subject.type(text: "turtle magic")

        delegate.resetState()

        try! subject.backspace()

        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(0))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(0))
    }

    func test_backspace_whenNoDelegate_deletesTheLastCharacter() {
        try! subject.startEditing()
        try! subject.type(text: "turtle magic")

        subject.delegate = nil

        try! subject.backspace()

        expect(self.subject.text).to(equal("turtle magi"))
    }

    func test_backspace_whenNoTextInTextView_doesNothing() {
        try! subject.startEditing()

        delegate.resetState()

        try! subject.backspace()

        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textChanges).to(equal([""]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(0))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(0))
    }

    func test_enter_convenienceMethod_startsEditingATextViewTypesTextAndStopsEditingAllInOneAction() {
        try! subject.enter(text: "turtle magic")

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

        try! textView.enter(text: "turtle magic")
        expect(textView.text).to(equal("turtle magic"))
        try! textView.startEditing()
        try! textView.backspace()
        expect(textView.text).to(equal("turtle magi"))
        try! textView.paste(text: "c woo")
        expect(textView.text).to(equal("turtle magic woo"))
        try! textView.stopEditing()
    }

    func test_whenUserInteractionIsDisabled_doesAbsolutelyNothingAndThrowsError() {
        subject.isUserInteractionEnabled = false
        expect { try self.subject.enter(text: "turtle magic") }.to(
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
