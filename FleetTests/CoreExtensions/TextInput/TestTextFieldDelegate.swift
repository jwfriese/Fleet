import UIKit

class TestTextFieldDelegate: NSObject {
    var didCallShouldBeginEditing: Bool = false
    var didCallDidBeginEditing: Bool = false
    var didCallShouldEndEditing: Bool = false
    var didCallDidEndEditing: Bool = false
    var didCallShouldClear: Bool = false
    var textChanges: [String] = []
    var textRanges: [NSRange] = []
    var shouldAllowBeginEditing = true
    var shouldAllowEndEditing = true
    var shouldAllowClearText = true
    var shouldAllowChangeText = true
}

extension TestTextFieldDelegate: UITextFieldDelegate {
    func resetState() {
        didCallShouldBeginEditing = false
        didCallDidBeginEditing = false
        didCallShouldEndEditing = false
        didCallDidEndEditing = false
        didCallShouldClear = false
        textChanges = []
        textRanges = []
        shouldAllowBeginEditing = true
        shouldAllowEndEditing = true
        shouldAllowClearText = true
        shouldAllowChangeText = true
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        didCallShouldBeginEditing = true
        return shouldAllowBeginEditing
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        didCallShouldEndEditing = true
        return shouldAllowEndEditing
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        didCallDidBeginEditing = true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        didCallDidEndEditing = true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        textRanges.append(range)
        if shouldAllowChangeText {
            textChanges.append(string)
        }
        return shouldAllowChangeText
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        didCallShouldClear = true
        return shouldAllowClearText
    }
}
