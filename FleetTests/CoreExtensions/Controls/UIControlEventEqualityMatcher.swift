import UIKit
import Nimble

func equal(_ expectedValue: UIControl.Event?) -> Predicate<UIControl.Event> {
    return Predicate { actualExpression in
        guard let expectedValue = expectedValue else {
            return PredicateResult(
                status: .doesNotMatch,
                message: .expectedTo("(use beNil() to match nils)")
            )
        }

        let errorMessage: ExpectationMessage =
            .expectedActualValueTo("equal <\(stringify(expectedValue))>")
        guard let actualValue = try actualExpression.evaluate() else {
            return PredicateResult(
                status: .doesNotMatch,
                message: errorMessage.appendedBeNilHint()
            )
        }

        let matches = actualValue.rawValue == expectedValue.rawValue
        if !matches {
            return PredicateResult(
                status: .doesNotMatch,
                message: .expectedCustomValueTo("equal \(stringify(expectedValue))", actual: "<\(stringify(actualValue))>")
            )
        }

        return PredicateResult(status: .matches, message: errorMessage)
    }.requireNonNil
}

func equal(_ expectedValue: [UIControl.Event]?) -> Predicate<[UIControl.Event]> {
    return Predicate { actualExpression in
        guard let expectedValue = expectedValue else {
            return PredicateResult(
                status: .doesNotMatch,
                message: .expectedTo("(use beNil() to match nils)")
            )
        }
        let errorMessage: ExpectationMessage =
            .expectedActualValueTo("equal <\(allToString(controlEvents: expectedValue))>")
        guard let actualValue = try actualExpression.evaluate() else {
            return PredicateResult(
                status: .doesNotMatch,
                message: errorMessage.appendedBeNilHint()
            )
        }

        let matches = actualValue.elementsEqual(expectedValue)

        if !matches {
            return PredicateResult(
                status: .doesNotMatch,
                message: .expectedCustomValueTo("equal \(stringify(expectedValue))", actual: "<\(allToString(controlEvents: actualValue))>")
            )
        }

        return PredicateResult(status: .matches, message: errorMessage)
    }
}

extension UIControl.Event {
    func toString() -> String {
        switch self {
        case UIControl.Event.touchDown:
            return "touchDown"
        case UIControl.Event.touchDownRepeat:
            return "touchDownRepeat"
        case UIControl.Event.touchDragInside:
            return "touchDragInside"
        case UIControl.Event.touchDragOutside:
            return "touchDragOutside"
        case UIControl.Event.touchDragEnter:
            return "touchDragEnter"
        case UIControl.Event.touchDragExit:
            return "touchDragExit"
        case UIControl.Event.touchUpInside:
            return "touchUpInside"
        case UIControl.Event.touchUpOutside:
            return "touchUpOutside"
        case UIControl.Event.touchCancel:
            return "touchCancel"
        case UIControl.Event.valueChanged:
            return "valueChanged"
        case UIControl.Event.editingDidBegin:
            return "editingDidBegin"
        case UIControl.Event.editingChanged:
            return "editingChanged"
        case UIControl.Event.editingDidEnd:
            return "editingDidEnd"
        case UIControl.Event.editingDidEndOnExit:
            return "editingDidEndOnExit"
        case UIControl.Event.allTouchEvents:
            return "allTouchEvents"
        case UIControl.Event.allEditingEvents:
            return "allEditingEvents"
        default:
            return "<unrecognized>"
        }
    }
}

fileprivate func allToString(controlEvents: [UIControl.Event]) -> String {
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
