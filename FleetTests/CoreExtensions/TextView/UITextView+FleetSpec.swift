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
}
