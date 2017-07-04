import UIKit
import Nimble

func equal(_ expectedValue: UIControlEvents?) -> Predicate<UIControlEvents> {
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
                message: .expectedCustomValueTo("equal \(stringify(expectedValue))", "<\(stringify(actualValue))>")
            )
        }

        return PredicateResult(status: .matches, message: errorMessage)
    }.requireNonNil
}

func equal(_ expectedValue: [UIControlEvents]?) -> Predicate<[UIControlEvents]> {
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
                message: .expectedCustomValueTo("equal \(stringify(expectedValue))", "<\(allToString(controlEvents: actualValue))>")
            )
        }

        return PredicateResult(status: .matches, message: errorMessage)
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
