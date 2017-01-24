import XCTest
import Nimble
import Fleet

class UITextField_FleetSpec: XCTestCase {
    var subject: UITextField!
    var delegate: TestTextFieldDelegate!

    override func setUp() {
        super.setUp()

        let tuple = createCompleteTextFieldAndDelegate()
        subject = tuple.textField
        delegate = tuple.delegate
        try! Test.embedViewIntoMainApplicationWindow(subject)
    }

    func createCompleteTextFieldAndDelegate() -> (textField: UITextField, delegate: TestTextFieldDelegate) {
        let textField = UITextField(frame: CGRect(x: 100,y: 100,width: 100,height: 100))
        let delegate = TestTextFieldDelegate()
        textField.delegate = delegate

        textField.isHidden = false
        textField.isEnabled = true

        return (textField, delegate)
    }

    func test_startEditing_whenTextViewIsFullyAvailable_putsFocusIntoTheTextView() {
        let error = subject.startEditing()

        expect(error).to(beNil())
        expect(self.subject.isFirstResponder).to(beTrue())
    }

    func test_startEditing_whenTextFieldFailsToBecomeFirstResponder_returnsError() {
        // If the text field is not in the window, it will never succeed to become first responder.
        let textFieldNotInWindow = UITextField(frame: CGRect(x: 100,y: 100,width: 100,height: 100))

        textFieldNotInWindow.isHidden = false
        textFieldNotInWindow.isEnabled = true

        let error = textFieldNotInWindow.startEditing()

        expect(error?.description).to(equal("Fleet error: UITextField failed to become first responder. Make sure that the field is a part of the key window's view hierarchy."))
        expect(textFieldNotInWindow.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenTextViewIsHidden_returnsError() {
        subject.isHidden = true

        let error = subject.startEditing()

        expect(error?.description).to(equal("Fleet error: Failed to start editing UITextField: Control is not visible."))
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_startEditing_whenTextViewIsNotEnabled_returnsError() {
        subject.isEnabled = false

        let error = subject.startEditing()

        expect(error?.description).to(equal("Fleet error: Failed to start editing UITextField: Control is not enabled."))
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
        expect(self.delegate.didCallShouldClear).to(beFalse())
    }

    func test_startEditing_whenAnotherTextFieldWasSelected_whenDelegateAllowsEditing_callsDelegateMethodsAppropriately() {
        let tuple = createCompleteTextFieldAndDelegate()
        let otherTextField = tuple.textField
        let otherDelegate = tuple.delegate
        try! Test.embedViewIntoMainApplicationWindow(otherTextField)

        otherDelegate.shouldAllowBeginEditing = true
        delegate.shouldAllowBeginEditing = true

        var error = otherTextField.startEditing()
        expect(error).to(beNil())

        error = subject.startEditing()

        expect(error).to(beNil())
        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beTrue())
        expect(otherDelegate.didCallShouldEndEditing).to(beTrue())
        expect(otherDelegate.didCallDidEndEditing).to(beTrue())
    }

    func test_startEditing_whenAnotherTextFieldWasSelected_whenDelegateDoesNotAllowEditing_callsDelegateMethodsAppropriately() {
        let tuple = createCompleteTextFieldAndDelegate()
        let otherTextField = tuple.textField
        let otherDelegate = tuple.delegate
        try! Test.embedViewIntoMainApplicationWindow(otherTextField)

        otherDelegate.shouldAllowBeginEditing = true
        delegate.shouldAllowBeginEditing = false

        var error = otherTextField.startEditing()
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

    func test_stopEditing_whenTextFieldIsFullyAvailable_removesFocusFromTheTextField() {
        let _ = subject.startEditing()
        let error = subject.stopEditing()

        expect(error).to(beNil())
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_stopEditing_whenNotFirstResponder_returnsError() {
        let error = subject.stopEditing()
        expect(error?.description).to(equal("Fleet error: Could not stop editing UITextField: Must start editing the text field before you can stop editing it."))
    }

    func test_stopEditing_whenDelegateAllowsEditingToEnd_callsDelegateMethodsAppropriately() {
        let _ = subject.startEditing()
        delegate.resetState()
        delegate.shouldAllowEndEditing = true

        let error = subject.stopEditing()

        expect(error).to(beNil())
        expect(self.delegate.didCallShouldEndEditing).to(beTrue())
        expect(self.delegate.didCallDidEndEditing).to(beTrue())
        expect(self.subject.isFirstResponder).to(beFalse())
    }

    func test_type_typesGivenTextIntoTextField() {
        let _ = subject.startEditing()
        let error = subject.type(text: "turtle magic")

        expect(error).to(beNil())
        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_type_whenNotFirstResponder_returnsError() {
        let error = subject.type(text: "turtle magic")
        expect(error?.description).to(equal("Fleet error: Could not type text into UITextField: Must start editing the text field before text can be typed into it."))
    }

    func test_type_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowChangeText = true
        let _ = subject.startEditing()
        let error = subject.type(text: "turtle magic")

        expect(error).to(beNil())
        expect(self.delegate.textChanges).to(equal(["t", "u", "r", "t", "l", "e", " ", "m", "a", "g", "i", "c"]))
        expect(self.delegate.textRanges.count).to(equal(12))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.textRanges[9].location).to(equal(9))
        expect(self.delegate.textRanges[9].length).to(equal(0))
    }

    func test_type_whenDelegateDoesNotAllowTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowChangeText = false
        let _ = subject.startEditing()
        let error = subject.type(text: "turtle magic")

        expect(error).to(beNil())
        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(12))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
        expect(self.delegate.textRanges[9].location).to(equal(0))
        expect(self.delegate.textRanges[9].length).to(equal(0))
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
        expect(error?.description).to(equal("Fleet error: Could not paste text into UITextField: Must start editing the text field before text can be pasted into it."))
    }

    func test_paste_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowChangeText = true
        let _ = subject.startEditing()
        let error = subject.paste(text: "turtle magic")

        expect(error).to(beNil())
        expect(self.delegate.textChanges).to(equal(["turtle magic"]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
    }

    func test_paste_whenDelegateDoesNotAllowTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowChangeText = false
        let _ = subject.startEditing()
        let error = subject.paste(text: "turtle magic")

        expect(error).to(beNil())
        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
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
        expect(error?.description).to(equal("Fleet error: Could not backspace in UITextField: Must start editing the text field before backspaces can be performed."))
    }

    func test_backspace_whenDelegateAllowsTextChanges_callsDelegateMethodsAppropriately() {
        delegate.shouldAllowChangeText = true
        let _ = subject.startEditing()
        let _ = subject.type(text: "turtle magic")

        delegate.resetState()

        let error = subject.backspace()

        expect(error).to(beNil())
        expect(self.delegate.textChanges).to(equal([""]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(11))
        expect(self.delegate.textRanges[0].length).to(equal(1))
    }

    func test_backspace_whenDelegateDoesNotAllowTextChanges_callsDelegateMethodsAppropriately() {
        let _ = subject.startEditing()
        let _ = subject.type(text: "turtle magic")

        delegate.resetState()

        delegate.shouldAllowChangeText = false
        let error = subject.backspace()

        expect(error).to(beNil())
        expect(self.delegate.textChanges).to(equal([]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(11))
        expect(self.delegate.textRanges[0].length).to(equal(1))
        expect(self.subject.text).to(equal("turtle magic"))
    }

    func test_backspace_whenNoDelegate_deletesTheLastCharacter() {
            let _ = subject.startEditing()
            let _ = subject.type(text: "turtle magic")

            subject.delegate = nil

            let error = subject.backspace()

            expect(error).to(beNil())
            expect(self.subject.text).to(equal("turtle magi"))
    }

    func test_backspace_whenNoTextInTextField_doesNothing() {
        let _ = subject.startEditing()

        delegate.resetState()

        let error = subject.backspace()

        expect(error).to(beNil())
        expect(self.subject.text).to(equal(""))
        expect(self.delegate.textChanges).to(equal([""]))
        expect(self.delegate.textRanges.count).to(equal(1))
        expect(self.delegate.textRanges[0].location).to(equal(0))
        expect(self.delegate.textRanges[0].length).to(equal(0))
    }

    func test_enter_convenienceMethod_startsEditingATextFieldTypesTextAndStopsEditingAllInOneAction() {
        let error = subject.enter(text: "turtle magic")

        expect(error).to(beNil())
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

    func test_whenTextFieldClearsOnEntry_whenDelegateAllowsClearing_clearsTextWhenEditingBegins() {
        subject.clearsOnBeginEditing = true
        delegate.shouldAllowClearText = true
        var error = subject.enter(text: "turtle magic")
        expect(error).to(beNil())
        expect(self.subject.text).to(equal("turtle magic"))

        error = subject.startEditing()
        expect(error).to(beNil())
        expect(self.subject.text).to(equal(""))
    }

    func test_whenTextFieldClearsOnEntry_whenDelegateDoesNotAllowClearing_doesNotClearTextWhenEditingBegins() {
        subject.clearsOnBeginEditing = true
        delegate.shouldAllowClearText = false
        var error = subject.enter(text: "turtle magic")
        expect(error).to(beNil())
        expect(self.subject.text).to(equal("turtle magic"))

        error = subject.startEditing()
        expect(error).to(beNil())
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

        var error = textField.enter(text: "turtle magic")
        expect(error).to(beNil())
        expect(textField.text).to(equal("turtle magic"))

        error = textField.startEditing()
        expect(error).to(beNil())

        error = textField.backspace()
        expect(error).to(beNil())
        expect(textField.text).to(equal("turtle magi"))

        error = textField.paste(text: "c woo")
        expect(error).to(beNil())
        expect(textField.text).to(equal("turtle magic woo"))
    }}
