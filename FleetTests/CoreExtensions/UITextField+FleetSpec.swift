import XCTest
import Nimble
import Fleet

class TestTextFieldDelegate: NSObject {
    var didCallShouldBeginEditing: Bool = false
    var didCallDidBeginEditing: Bool = false
    var didCallShouldEndEditing: Bool = false
    var didCallDidEndEditing: Bool = false
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
        textChanges = []
    }

    func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
        didCallShouldBeginEditing = true
        return true
    }

    func textFieldShouldEndEditing(textField: UITextField) -> Bool {
        didCallShouldEndEditing = true
        return true
    }

    func textFieldDidBeginEditing(textField: UITextField) {
        didCallDidBeginEditing = true
    }

    func textFieldDidEndEditing(textField: UITextField) {
        didCallDidEndEditing = true
    }

    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        textChanges.append(string)
        return true
    }
}

class UITextField_FleetSpec: XCTestCase {
    var textField: UITextField!
    var delegate: TestTextFieldDelegate!

    override func setUp() {
        super.setUp()
        textField = UITextField(frame: CGRectMake(100,100,100,100))
        delegate = TestTextFieldDelegate()
        textField.delegate = delegate
    }

    func test_enter_entersTheTextField() {
        try! textField.enter()
        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beTrue())
    }

    func test_enter_whenAlreadyEntered_doesNothing() {
        try! textField.enter()
        delegate.resetState()

        try! textField.enter()
        expect(self.delegate.didCallShouldBeginEditing).to(beFalse())
        expect(self.delegate.didCallDidBeginEditing).to(beFalse())
    }

    func test_enter_whenDisabled_throwsError() {
        textField.enabled = false
        expect { try self.textField.enter() }.to(throwError(FLTTextFieldError.DisabledTextFieldError))
    }


    func test_enter_whenNoDelegate_stillSendsEditingDidBeginEvent() {
        textField.delegate = nil
        let testTarget = TestTextFieldTarget()
        textField.addTarget(testTarget,
                            action: #selector(TestTextFieldTarget.doFunc),
                            forControlEvents: .EditingDidBegin
        )

        try! textField.enter()
        expect(testTarget.didCallDo).to(beTrue())
    }

    func test_leave_leavesTheEnteredTextField() {
        try! textField.enter()
        delegate.resetState()

        textField.leave()
        expect(self.delegate.didCallShouldEndEditing).to(beTrue())
        expect(self.delegate.didCallDidEndEditing).to(beTrue())
    }

    func test_leave_beforeHavingEnteredTextField_doesNothing() {
        textField.leave()
        expect(self.delegate.didCallShouldEndEditing).to(beFalse())
        expect(self.delegate.didCallDidEndEditing).to(beFalse())
    }

    func test_leave_whenNoDelegate_stillSendsEditingDidEndEvent() {
        textField.delegate = nil
        try! textField.enter()
        let testTarget = TestTextFieldTarget()
        textField.addTarget(testTarget,
                            action: #selector(TestTextFieldTarget.doFunc),
                            forControlEvents: .EditingDidEnd
        )

        textField.leave()
        expect(testTarget.didCallDo).to(beTrue())
    }

    func test_enterText_entersTextFieldTypesTextAndLeavesTextField() {
        try! textField.enterText("turtle")

        expect(self.delegate.didCallShouldBeginEditing).to(beTrue())
        expect(self.delegate.didCallDidBeginEditing).to(beTrue())
        expect(self.delegate.textChanges).to(equal(["t", "u", "r", "t", "l", "e"]))
        expect(self.delegate.didCallShouldEndEditing).to(beTrue())
        expect(self.delegate.didCallDidEndEditing).to(beTrue())
    }

    func test_enterText_whenThereIsADelegate_actuallyEntersTheText() {
        try! textField.enterText("turtle")
        expect(self.textField.text).to(equal("turtle"))
    }

    func test_enterText_whenDisabled_throwsError() {
        textField.enabled = false
        expect { try self.textField.enterText("turtle") }.to(throwError(FLTTextFieldError.DisabledTextFieldError))
    }

    func test_typeText_typesTextIntoTextField() {
        try! textField.enter()
        delegate.resetState()

        textField.typeText("turtle")
        expect(self.delegate.textChanges).to(equal(["t", "u", "r", "t", "l", "e"]))
    }

    func test_typeText_whenThereIsADelegate_actuallyTypesTheText() {
        try! textField.enter()
        textField.typeText("turtle")
        expect(self.textField.text).to(equal("turtle"))
    }

    func test_typeText_whenNeverEnteredTextField_doesNothing() {
        textField.typeText("turtle")
        expect(self.delegate.textChanges).to(equal([]))
    }

    func test_typeText_whenNoDelegate_stillSendsEditingChangedEvent() {
        textField.delegate = nil
        try! textField.enter()
        let testTarget = TestTextFieldTarget()
        textField.addTarget(testTarget,
                            action: #selector(TestTextFieldTarget.doFunc),
                            forControlEvents: .EditingChanged
        )

        textField.typeText("turtle")
        expect(testTarget.didCallDo).to(beTrue())
    }

    func test_typeText_whenNoDelegate_stillUpdatesText() {
        textField.delegate = nil
        try! textField.enter()
        textField.typeText("turtle")
        expect(self.textField.text).to(equal("turtle"))
    }

    func test_pasteText_typesTextIntoTextFieldAllAtOnce() {
        try! textField.enter()
        delegate.resetState()

        textField.pasteText("turtle")
        expect(self.delegate.textChanges).to(equal(["turtle"]))
    }

    func test_pasteText_whenNeverEnteredTextField_doesNothing() {
        textField.pasteText("turtle")
        expect(self.delegate.textChanges).to(equal([]))
    }

    func test_pasteText_whenNoDelegate_stillSendsEditingChangedEvent() {
        textField.delegate = nil
        try! textField.enter()
        let testTarget = TestTextFieldTarget()
        textField.addTarget(testTarget,
                            action: #selector(TestTextFieldTarget.doFunc),
                            forControlEvents: .EditingChanged
        )

        textField.pasteText("turtle")
        expect(testTarget.didCallDo).to(beTrue())
    }

    func test_pasteText_whenNoDelegate_stillUpdatesText() {
        textField.delegate = nil
        try! textField.enter()
        textField.pasteText("turtle")
        expect(self.textField.text).to(equal("turtle"))
    }
}
