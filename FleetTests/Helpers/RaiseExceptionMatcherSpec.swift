import XCTest
import Nimble

class RaiseExceptionMatcherSpec: XCTestCase {
    func test_matchesTheActualExceptionAndEvaluatesOnce() {
        var evaluations = 0
        var captured: NSException?
        expect {
            evaluations += 1
            NSException(name: NSExceptionName("Expected"), reason: "reason", userInfo: ["key": "value"]).raise()
        }.to(raiseException(named: "Expected", reason: "reason", userInfo: ["key": "value"]) { captured = $0 })
        XCTAssertEqual(evaluations, 1)
        XCTAssertEqual(captured?.name.rawValue, "Expected")
        XCTAssertEqual(captured?.userInfo?["key"] as? String, "value")
    }

    func test_rejectsMissingOrMismatchedExceptions() {
        expect {}.toNot(raiseException())
        expect { NSException(name: NSExceptionName("Actual"), reason: "reason", userInfo: nil).raise() }
            .toNot(raiseException(named: "Different"))
        expect { NSException(name: NSExceptionName("Actual"), reason: "reason", userInfo: nil).raise() }
            .toNot(raiseException(reason: "different reason"))
        expect { NSException(name: NSExceptionName("Actual"), reason: nil, userInfo: ["key": "value"]).raise() }
            .toNot(raiseException(userInfo: ["key": "different value"]))
    }
}
