import XCTest
import UIKit
import Fleet
import Nimble

fileprivate class ChildClassUIViewController: UIViewController {}
fileprivate class GrandchildClassUIViewController: ChildClassUIViewController {}

class IsClassKindOfSpec: XCTestCase {
    func test_isClassKindOf_whenFirstArgClassIsIdentifcalToSecondArgClass_returnsTrue() {
        expect(FleetObjC.isClass(UIViewController.self, kindOf: UIViewController.self)).to(beTrue())
    }

    func test_isClassKindOf_whenFirstArgClassIsASubclassOfSecondArgClass_returnsTrue() {
        expect(FleetObjC.isClass(GrandchildClassUIViewController.self, kindOf: UIViewController.self)).to(beTrue())
        expect(FleetObjC.isClass(GrandchildClassUIViewController.self, kindOf: ChildClassUIViewController.self)).to(beTrue())
        expect(FleetObjC.isClass(ChildClassUIViewController.self, kindOf: UIViewController.self)).to(beTrue())
    }

    func test_isClassKindOf_whenFirstArgClassIsNotASubclassOfSecondArgClass_returnsFalse() {
        expect(FleetObjC.isClass(NSData.self, kindOf: UIViewController.self)).to(beFalse())
        expect(FleetObjC.isClass(ChildClassUIViewController.self, kindOf: GrandchildClassUIViewController.self)).to(beFalse())
    }
}
