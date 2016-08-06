import XCTest

protocol Reporter {
    func reportError(errorMessage: String, testCase: XCTestCase)
}

class ReporterImpl: Reporter {
    func reportError(errorMessage: String, testCase: XCTestCase) {
        testCase.recordFailureWithDescription(errorMessage, inFile: #file, atLine: #line, expected: false)
    }
}
