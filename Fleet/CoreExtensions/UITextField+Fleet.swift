import UIKit

private var isFocusedAssociatedKey: UInt = 0

extension UITextField {
    private var isFocused: Bool? {
        get {
            let isFocusedValue = objc_getAssociatedObject(self, &isFocusedAssociatedKey) as? NSNumber
            return isFocusedValue?.boolValue
        }
        
        set {
            var isFocusedValue: NSNumber?
            if let newValue = newValue {
                isFocusedValue = NSNumber(bool: newValue)
            }
            
            objc_setAssociatedObject(self, &isFocusedAssociatedKey, isFocusedValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
}

public enum FLTTextFieldError: ErrorType {
    case DisabledTextFieldError
}

extension UITextField {
    public func enter() throws {
        if isFocused != nil && isFocused! {
            Logger.logWarning("Attempting to enter a UITextField that was already entered")
            return
        }
        
        if !enabled {
            throw FLTTextFieldError.DisabledTextFieldError
        }
        
        isFocused = true
        if let delegate = delegate {
            _ = delegate.textFieldShouldBeginEditing?(self)
            _ = delegate.textFieldDidBeginEditing?(self)
            self.sendActionsForControlEvents(.EditingDidBegin)
        }
    }
    
    public func leave() {
        if isFocused == nil || !isFocused! {
            Logger.logWarning("Attempting to leave a UITextField that was never entered")
            return
        }
        
        if let delegate = delegate {
            _ = delegate.textFieldShouldEndEditing?(self)
            _ = delegate.textFieldDidEndEditing?(self)
            self.sendActionsForControlEvents(.EditingDidEnd)
        }
        
        isFocused = false
    }
    
    public func enterText(text: String) throws {
        try self.enter()
        self.typeText(text)
        self.leave()
    }
    
    public func typeText(text: String) {
        if isFocused == nil || !isFocused! {
            Logger.logWarning("Attempting to type \"\(text)\" into a UITextField that was never entered")
            return
        }
        
        if let delegate = delegate {
            for (index, char) in text.characters.enumerate() {
                _ = delegate.textField?(self, shouldChangeCharactersInRange: NSRange.init(location: index, length: 1), replacementString: String(char))
                self.sendActionsForControlEvents(.EditingChanged)
            }
        }
    }
    
    public func pasteText(text: String) {
        if isFocused == nil || !isFocused! {
            Logger.logWarning("Attempting to paste \"\(text)\" into a UITextField that was never entered")
            return
        }
        
        if let delegate = delegate {
            let length = text.characters.count
            _ = delegate.textField?(self, shouldChangeCharactersInRange: NSRange.init(location: 0, length: length), replacementString: text)
            self.sendActionsForControlEvents(.EditingChanged)
        }
    }
}
