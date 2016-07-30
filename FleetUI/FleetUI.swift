import XCTest

public class FleetUI {
    public class func createUser(xcApp: XCUIApplication, testCase xcTestCase: XCTestCase) -> User {
        return User(xcApp: xcApp, testCase: xcTestCase, reporter: ReporterImpl())
    }
}
