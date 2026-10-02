import Foundation
import Nimble

// Keep the existing exception assertions while Nimble is installed through SwiftPM.
// Catch the actual NSException, independently of Fleet's own exception conversion.
func raiseException<T>(
    named name: String? = nil,
    reason: String? = nil,
    userInfo: [AnyHashable: Any]? = nil,
    closure: ((NSException) -> Void)? = nil
) -> Matcher<T> {
    return Matcher { expression in
        var evaluationError: Error?
        let exception = FleetTestExceptionCatcher.exception(from: {
            do {
                _ = try expression.evaluate()
            } catch {
                evaluationError = error
            }
        })
        if let evaluationError = evaluationError {
            throw evaluationError
        }

        let expected = "raise exception" + (name.map { " named '\($0)'" } ?? "")
            + (reason.map { " with reason '\($0)'" } ?? "")
        guard let exception = exception else {
            return MatcherResult(status: .doesNotMatch, message: .expectedCustomValueTo(expected, actual: "no exception"))
        }
        closure?(exception)
        let matches = (name == nil || exception.name.rawValue == name)
            && (reason == nil || exception.reason == reason)
            && (userInfo == nil || NSDictionary(dictionary: exception.userInfo ?? [:]).isEqual(to: userInfo!))
        return MatcherResult(
            status: matches ? .matches : .doesNotMatch,
            message: .expectedCustomValueTo(expected, actual: "\(exception.name.rawValue): \(exception.reason ?? "<no reason>")")
        )
    }
}
