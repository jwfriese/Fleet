import UIKit

class TestTextViewDelegate: NSObject, UITextViewDelegate {
    var didCallShouldBeginEditing: Bool = false
    var shouldAllowBeginEditing = true
    var didCallDidBeginEditing: Bool = false
    var didCallShouldEndEditing: Bool = false
    var shouldAllowEndEditing = true
    var didCallDidEndEditing: Bool = false
    var textChanges: [String] = []
    var textRanges: [NSRange] = []
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
        didChangeCallCount = 0
        didChangeSelectionCallCount = 0
    }

    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        didCallShouldBeginEditing = true
        return shouldAllowBeginEditing
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        didCallShouldEndEditing = true
        return shouldAllowEndEditing
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        didCallDidBeginEditing = true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        didCallDidEndEditing = true
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
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
