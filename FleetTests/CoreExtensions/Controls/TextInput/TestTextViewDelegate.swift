import UIKit

@MainActor
class TestTextViewDelegate: NSObject, UITextViewDelegate {
    var didCallShouldBeginEditing: Bool = false
    var shouldAllowBeginEditing = true
    var didCallDidBeginEditing: Bool = false
    var didCallShouldEndEditing: Bool = false
    var shouldAllowEndEditing = true
    var didCallDidEndEditing: Bool = false
    var textChanges: [String] = []
    var textRanges: [NSRange] = []
    var callLog: [String] = []
    var shouldAllowTextChanges = true
    var didChangeCallCount = 0
    var didChangeSelectionCallCount = 0

    func resetState() {
        didCallShouldBeginEditing = false
        shouldAllowBeginEditing = true
        didCallDidBeginEditing = false
        didCallShouldEndEditing = false
        shouldAllowEndEditing = true
        didCallDidEndEditing = false
        textChanges = []
        textRanges = []
        callLog = []
        didChangeCallCount = 0
        didChangeSelectionCallCount = 0
    }

    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        callLog.append("textViewShouldBeginEditing")
        didCallShouldBeginEditing = true
        return shouldAllowBeginEditing
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        callLog.append("textViewShouldEndEditing")
        didCallShouldEndEditing = true
        return shouldAllowEndEditing
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        callLog.append("textViewDidBeginEditing")
        didCallDidBeginEditing = true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        callLog.append("textViewDidEndEditing")
        didCallDidEndEditing = true
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        callLog.append("shouldChange")
        textRanges.append(range)
        if shouldAllowTextChanges {
            textChanges.append(text)
        }
        return shouldAllowTextChanges
    }

    func textViewDidChange(_ textView: UITextView) {
        didChangeCallCount += 1
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        didChangeSelectionCallCount += 1
    }

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        return true
    }

    func textView(_ textView: UITextView, shouldInteractWith textAttachment: NSTextAttachment, in characterRange: NSRange) -> Bool {
        return true
    }
}
