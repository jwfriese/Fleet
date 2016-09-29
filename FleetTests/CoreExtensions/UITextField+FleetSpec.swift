import XCTest
import Nimble
import Fleet

class TestTextFieldDelegate: NSObject {
    var didCallShouldBeginEditing: Bool = false
    var didCallDidBeginEditing: Bool = false
    var didCallShouldEndEditing: Bool = false
    var didCallDidEndEditing: Bool = false
    var didCallShouldClear: Bool = false
    var textChanges: [String] = []
}

class TestTextFieldTarget: NSObject {
    var didCallDo: Bool = false

    func doFunc() {
        didCallDo = true
    }
}

extension TestTextFieldDelegate: UITextFieldDelegate {
    func resetState() {
        didCallShouldBeginEditing = false
        didCallDidBeginEditing = false
        didCallShouldEndEditing = false
        didCallDidEndEditing = false
        didCallShouldClear = false
        textChanges = []
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        didCallShouldBeginEditing = true
        return true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        didCallShouldEndEditing = true
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        didCallDidBeginEditing = true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        didCallDidEndEditing = true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        textChanges.append(string)
        return true
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        didCallShouldClear = true
        return true
    }
}

class UITextField_FleetSpec: XCTestCase {
    var textField: UITextField!
    var delegate: TestTextFieldDelegate!

    override func setUp() {
        super.setUp()
        textField = UITextField(frame: CGRect(x: 100,y: 100,width: 100,height: 100))
        delegate = TestTextFieldDelegate()
        textField.delegate = delegate
    }

    func test_enter_entersTheTextField() {
        try! textField.focus()
        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beTrue())
    }

    func test_enter_whenAlreadyEntered_doesNothing() {
        try! textField.focus()
        delegate.resetState()

        try! textField.focus()
        expect(self.delegate.didCallShouldBeginEditing).to(beFalse())
        expect(self.delegate.didCallDidBeginEditing).to(beFalse())
    }

    func test_enter_whenDisabled_throwsError() {
        textField.isEnabled = false
        expect { try self.textField.focus() }.to(throwError(FLTTextFieldError.disabledTextFieldError))
    }


    func test_enter_whenNoDelegate_stillSendsEditingDidBeginEvent() {
        textField.delegate = nil
        let testTarget = TestTextFieldTarget()
        textField.addTarget(testTarget,
                            action: #selector(TestTextFieldTarget.doFunc),
                            for: .editingDidBegin
        )

        try! textField.focus()
        expect(testTarget.didCallDo).to(beTrue())
    }

    func test_leave_leavesTheEnteredTextField() {
        try! textField.focus()
        delegate.resetState()

        textField.unfocus()
        expect(self.delegate.didCallShouldEndEditing).to(beTrue())
        expect(self.delegate.didCallDidEndEditing).to(beTrue())
    }

    func test_leave_beforeHavingEnteredTextField_doesNothing() {
        textField.unfocus()
        expect(self.delegate.didCallShouldEndEditing).to(beFalse())
        expect(self.delegate.didCallDidEndEditing).to(beFalse())
    }

    func test_leave_whenNoDelegate_stillSendsEditingDidEndEvent() {
        textField.delegate = nil
        try! textField.focus()
        let testTarget = TestTextFieldTarget()
        textField.addTarget(testTarget,
                            action: #selector(TestTextFieldTarget.doFunc),
                            for: .editingDidEnd
        )

        textField.unfocus()
        expect(testTarget.didCallDo).to(beTrue())
    }

    func test_enterText_entersTextFieldTypesTextAndLeavesTextField() {
        try! textField.enter("turtle")

        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beTrue())
        expect(self.delegate.textChanges).to(equal(["t", "u", "r", "t", "l", "e"]))
        expect(self.delegate.didCallShouldEndEditing).to(beTrue())
        expect(self.delegate.didCallDidEndEditing).to(beTrue())
    }

    func test_enterText_whenThereIsADelegate_actuallyEntersTheText() {
        try! textField.enter("turtle")
        expect(self.textField.text).to(equal("turtle"))
    }

    func test_enterText_whenDisabled_throwsError() {
        textField.isEnabled = false
        expect { try self.textField.enter("turtle") }.to(throwError(FLTTextFieldError.disabledTextFieldError))
    }

    func test_typeText_typesTextIntoTextField() {
        try! textField.focus()
        delegate.resetState()

        textField.type("turtle")
        expect(self.delegate.textChanges).to(equal(["t", "u", "r", "t", "l", "e"]))
    }

    func test_typeText_whenThereIsADelegate_actuallyTypesTheText() {
        try! textField.focus()
        textField.type("turtle")
        expect(self.textField.text).to(equal("turtle"))
    }

    func test_typeText_whenNeverEnteredTextField_doesNothing() {
        textField.type("turtle")
        expect(self.delegate.textChanges).to(equal([]))
    }

    func test_typeText_whenNoDelegate_stillSendsEditingChangedEvent() {
        textField.delegate = nil
        try! textField.focus()
        let testTarget = TestTextFieldTarget()
        textField.addTarget(testTarget,
                            action: #selector(TestTextFieldTarget.doFunc),
                            for: .editingChanged
        )

        textField.type("turtle")
        expect(testTarget.didCallDo).to(beTrue())
    }

    func test_typeText_whenNoDelegate_stillUpdatesText() {
        textField.delegate = nil
        try! textField.focus()
        textField.type("turtle")
        expect(self.textField.text).to(equal("turtle"))
    }

    func test_pasteText_typesTextIntoTextFieldAllAtOnce() {
        try! textField.focus()
        delegate.resetState()

        textField.paste(text: "turtle")
        expect(self.delegate.textChanges).to(equal(["turtle"]))
    }

    func test_pasteText_whenNeverEnteredTextField_doesNothing() {
        textField.paste(text: "turtle")
        expect(self.delegate.textChanges).to(equal([]))
    }

    func test_pasteText_whenNoDelegate_stillSendsEditingChangedEvent() {
        textField.delegate = nil
        try! textField.focus()
        let testTarget = TestTextFieldTarget()
        textField.addTarget(testTarget,
                            action: #selector(TestTextFieldTarget.doFunc),
                            for: .editingChanged
        )

        textField.paste(text: "turtle")
        expect(testTarget.didCallDo).to(beTrue())
    }

    func test_pasteText_whenNoDelegate_stillUpdatesText() {
        textField.delegate = nil
        try! textField.focus()
        textField.paste(text: "turtle")
        expect(self.textField.text).to(equal("turtle"))
    }

    func test_clearText_shouldActuallyClearTheText() {
        textField.text = "some text"
        textField.clearText()
        expect(self.textField.text).to(equal(""))
    }

    func test_clearText_whenNoDelegate_stillClearsText() {
        textField.delegate = nil
        textField.text = "some text"
        textField.clearText()
        expect(self.textField.text).to(equal(""))
    }

    func test_clearText_notifiesTheDelegate() {
        textField.clearText()
        expect(self.delegate.didCallShouldClear).to(beTrue())
    }
}
