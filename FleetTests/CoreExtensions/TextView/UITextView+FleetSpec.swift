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
        let error = subject.startEditing()

        expect(error).to(beNil())
        expect(self.subject.isFirstResponder).to(beTrue())
    }

    func test_startEditing_whenTextViewFailsToBecomeFirstResponder_returnsError() {
        // If the text view is not in the window, it will never succeed to become first responder.
        let textViewNotInWindow = UITextView(frame: CGRect(x: 100,y: 100,width: 100,height: 100))

        textViewNotInWindow.isHidden = false
        textViewNotInWindow.isEditable = true
        textViewNotInWindow.isSelectable = true

        let error = textViewNotInWindow.startEditing()

        expect(error?.description).to(equal("Fleet error: UITextView failed to become first responder. Make sure that the view is a part of the key window's view hierarchy."))
        expect(textViewNotInWindow.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenTextViewIsHidden_returnsError() {
        subject.isHidden = true

        let error = subject.startEditing()

        expect(error?.description).to(equal("Fleet error: Failed to start editing UITextView: Control is not visible."))
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenTextViewIsNotSelectable_returnsError() {
        subject.isSelectable = false

        let error = subject.startEditing()

        expect(error?.description).to(equal("Fleet error: Failed to start editing UITextView: Control is not selectable."))
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenTextViewIsNotEditable_returnsError() {
        subject.isEditable = false

        let error = subject.startEditing()

        expect(error?.description).to(equal("Fleet error: Failed to start editing UITextView: Control is not editable."))
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenDelegateAllowsEditing_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowBeginEditing = true
        let error = subject.startEditing()

        expect(error).to(beNil())
        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beTrue())
    }

    func test_startEditing_whenDelegateDoesNotAllowEditing_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowBeginEditing = false
        let error = subject.startEditing()

        expect(error).to(beNil())
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

        var error = otherTextView.startEditing()
        expect(error).to(beNil())

        error = subject.startEditing()

        expect(error).to(beNil())
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

        var error = otherTextView.startEditing()
        expect(error).to(beNil())

        error = subject.startEditing()

        expect(error).to(beNil())
        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beFalse())
        expect(otherDelegate.didCallShouldEndEditing).to(beFalse())
        expect(otherDelegate.didCallDidEndEditing).to(beFalse())
    }

    func test_startEditing_whenAlreadyFirstResponder_doesNothing() {
        delegate.shouldAllowBeginEditing = true

        var error = subject.startEditing()
        expect(error).to(beNil())

        delegate.resetState()

        error = subject.startEditing()
        expect(error).to(beNil())
        expect(self.delegate.didCallShouldBeginEditing).to(beFalse())
    }

    func test_type_typesGivenTextIntoTextView() {
        let _ = subject.startEditing()
        let error = subject.type(text: "turtle magic")

        expect(error).to(beNil())
        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_type_whenNotFirstResponder_returnsError() {
        let error = subject.type(text: "turtle magic")
        expect(error?.description).to(equal("Fleet error: Could not type text into UITextView: Must start editing the text view before text can be typed into it."))
    }

    func test_type_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = true
        let _ = subject.startEditing()
        let error = subject.type(text: "turtle magic")

        expect(error).to(beNil())
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
        let _ = subject.startEditing()
        let error = subject.type(text: "turtle magic")

        expect(error).to(beNil())
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
        let _ = subject.startEditing()
        subject.delegate = nil
        let error = subject.type(text: "turtle magic")

        expect(error).to(beNil())
        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_paste_putsGivenTextIntoTextView() {
        let _ = subject.startEditing()
        let error = subject.paste(text: "turtle magic")

        expect(error).to(beNil())
        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_paste_whenNotFirstResponder_returnsError() {
        let error = subject.paste(text: "turtle magic")
        expect(error?.description).to(equal("Fleet error: Could not paste text into UITextView: Must start editing the text view before text can be pasted into it."))
    }

    func test_paste_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = true
        let _ = subject.startEditing()
        let error = subject.paste(text: "turtle magic")

        expect(error).to(beNil())
        expect(self.delegate.textChanges).to(equal(["turtle magic"]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(1))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(1))
    }

    func test_paste_whenDelegateDoesNotAllowTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = false
        let _ = subject.startEditing()
        let error = subject.paste(text: "turtle magic")

        expect(error).to(beNil())
        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(0))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(0))
    }

    func test_backspace_deletesTheLastCharacter() {
        func test_type_typesGivenTextIntoTextView() {
            let _ = subject.startEditing()
            let _ = subject.type(text: "turtle magic")

            delegate.resetState()

            let error = subject.backspace()

            expect(error).to(beNil())
            expect(self.subject.text).to(equal("turtle magi"))
        }
    }

    func test_backspace_whenNotFirstResponder_returnsError() {
        let error = subject.backspace()
        expect(error?.description).to(equal("Fleet error: Could not backspace in UITextView: Must start editing the text view before backspaces can be performed."))
    }

    func test_backspace_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = true
        let _ = subject.startEditing()
        let _ = subject.type(text: "turtle magic")

        delegate.resetState()

        let error = subject.backspace()

        expect(error).to(beNil())
        expect(self.delegate.textChanges).to(equal([""]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(11))
        expect(self.delegate.textRanges[0].length).to(equal(1))
        expect(self.delegate.didChangeCallCount).to(equal(1))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(1))
    }

    func test_backspace_whenDelegateDoesNotAllowTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowTextChanges = false
        let _ = subject.startEditing()
        let _ = subject.type(text: "turtle magic")

        delegate.resetState()

        let error = subject.backspace()

        expect(error).to(beNil())
        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(0))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(0))
    }

    func test_backspace_whenNoDelegate_deletesTheLastCharacter() {
        func test_type_typesGivenTextIntoTextView() {
            let _ = subject.startEditing()
            let _ = subject.type(text: "turtle magic")

            subject.delegate = nil

            let error = subject.backspace()

            expect(error).to(beNil())
            expect(self.subject.text).to(equal("turtle magi"))
        }
    }

    func test_backspace_whenNoTextInTextView_doesNothing() {
        let _ = subject.startEditing()

        delegate.resetState()

        let error = subject.backspace()

        expect(error).to(beNil())
        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textChanges).to(equal([""]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.didChangeCallCount).to(equal(0))
        expect(self.delegate.didChangeSelectionCallCount).to(equal(0))
    }
}
