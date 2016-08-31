import Nimble

func containObjectSatisfying<S: SequenceType, T where S.Generator.Element == T>(predicate: (T) -> Bool) -> NonNilMatcherFunc<S> {

    return NonNilMatcherFunc { actualExpression, failureMessage in
        failureMessage.postfixMessage = "contain object satisfying"
        if let sequence = try actualExpression.evaluate() {
            for object in sequence {
                if predicate(object) {
                    return true
                }
            }

            return false
        }

        return false
    }
}
