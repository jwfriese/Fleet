import Nimble

func containObjectSatisfying<S: Sequence, T>(_ predicate: @escaping (T) -> Bool) -> NonNilMatcherFunc<S> where S.Iterator.Element == T {

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
