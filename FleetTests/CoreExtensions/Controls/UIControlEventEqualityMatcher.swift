import UIKit
import Nimble

func equal(_ expectedValue: UIControlEvents?) -> NonNilMatcherFunc<UIControlEvents> {
    return NonNilMatcherFunc { actualExpression, failureMessage in
        guard let expectedValue = expectedValue else {
            failureMessage.postfixMessage = "equal <nil>"
            failureMessage.postfixActual = " (use beNil() to match nils)"
            return false
        }
        failureMessage.postfixMessage = "equal <\(expectedValue.toString())>"
        guard let actualValue = try actualExpression.evaluate() else {
            failureMessage.postfixActual = " (use beNil() to match nils)"
            return false
        }

        let matches = actualValue.rawValue == expectedValue.rawValue
        if !matches {
            failureMessage.postfixActual = ", but was <\(actualValue.toString())>"
        }

        return matches
    }
}

func equal(_ expectedValue: [UIControlEvents]?) -> NonNilMatcherFunc<[UIControlEvents]> {
    return NonNilMatcherFunc { actualExpression, failureMessage in
        guard let expectedValue = expectedValue else {
            failureMessage.postfixMessage = "equal <nil>"
            failureMessage.postfixActual = " (use beNil() to match nils)"
            return false
        }
        failureMessage.postfixMessage = "equal <\(allToString(controlEvents: expectedValue))>"
        guard let actualValue = try actualExpression.evaluate() else {
            failureMessage.postfixActual = " (use beNil() to match nils)"
            return false
        }

        let matches = actualValue.elementsEqual(expectedValue)

        if !matches {
            failureMessage.actualValue = ", but was <\(allToString(controlEvents: actualValue))>"
        }

        return matches
    }
}

extension UIControlEvents {
    func toString() -> String {
        switch self {
        case UIControlEvents.touchDown:
            return "touchDown"
        case UIControlEvents.touchDownRepeat:
            return "touchDownRepeat"
        case UIControlEvents.touchDragInside:
            return "touchDragInside"
        case UIControlEvents.touchDragOutside:
            return "touchDragOutside"
        case UIControlEvents.touchDragEnter:
            return "touchDragEnter"
        case UIControlEvents.touchDragExit:
            return "touchDragExit"
        case UIControlEvents.touchUpInside:
            return "touchUpInside"
        case UIControlEvents.touchUpOutside:
            return "touchUpOutside"
        case UIControlEvents.touchCancel:
            return "touchCancel"
        case UIControlEvents.valueChanged:
            return "valueChanged"
        case UIControlEvents.editingDidBegin:
            return "editingDidBegin"
        case UIControlEvents.editingChanged:
            return "editingChanged"
        case UIControlEvents.editingDidEnd:
            return "editingDidEnd"
        case UIControlEvents.editingDidEndOnExit:
            return "editingDidEndOnExit"
        case UIControlEvents.allTouchEvents:
            return "allTouchEvents"
        case UIControlEvents.allEditingEvents:
            return "allEditingEvents"
        default:
            return "<unrecognized>"
        }
    }
}

fileprivate func allToString(controlEvents: [UIControlEvents]) -> String {
    var string = "["
    for event in controlEvents {
        string += "\(event.toString()), "
    }

    if !controlEvents.isEmpty {
        string.remove(at: string.index(before: string.endIndex))
        string.remove(at: string.index(before: string.endIndex))
    }

    string += "]"
    return string
}
