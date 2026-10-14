import UIKit

@MainActor
class TestTextFieldDelegate: NSObject {
    var didCallShouldBeginEditing: Bool = false
    var didCallDidBeginEditing: Bool = false
    var didCallShouldEndEditing: Bool = false
    var didCallDidEndEditing: Bool = false
    var didCallShouldClear: Bool = false
    var textChanges: [String] = []
    var textRanges: [NSRange] = []
    var callLog: [String] = []
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
        callLog = []
        shouldAllowBeginEditing = true
        shouldAllowEndEditing = true
        shouldAllowClearText = true
        shouldAllowChangeText = true
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        callLog.append("textFieldShouldBeginEditing")
        didCallShouldBeginEditing = true
        return shouldAllowBeginEditing
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        callLog.append("textFieldShouldEndEditing")
        didCallShouldEndEditing = true
        return shouldAllowEndEditing
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        callLog.append("textFieldDidBeginEditing")
        didCallDidBeginEditing = true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        callLog.append("textFieldDidEndEditing")
        didCallDidEndEditing = true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        callLog.append("shouldChange")
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
