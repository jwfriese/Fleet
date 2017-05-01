import XCTest
import Nimble
import Fleet

class UITextView_FleetSpec_iOS: XCTestCase {
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
    
    func test_startEditing_whenTextViewIsNotEditable_raisesException() {
        subject.isEditable = false
        
        expect { try self.subject.startEditing() }.to(
            raiseException(named: "Fleet.TextViewError", reason: "UITextView unavailable for editing: Text view is not editable.", userInfo: nil, closure: nil)
        )
        expect(self.subject.isFirstResponder).to(beFalse())
    }
}
