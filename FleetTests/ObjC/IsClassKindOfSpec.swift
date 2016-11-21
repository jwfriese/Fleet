import XCTest
import UIKit
import Fleet
import Nimble

fileprivate class ChildClassUIViewController: UIViewController {}
fileprivate class GrandchildClassUIViewController: ChildClassUIViewController {}

class IsClassKindOfSpec: XCTestCase {
    func test_isClassKindOf_whenFirstArgClassIsIdentifcalToSecondArgClass_returnsTrue() {
        expect(FleetObjC._isClass(UIViewController.self, kindOf: UIViewController.self)).to(beTrue())
    }

    func test_isClassKindOf_whenFirstArgClassIsASubclassOfSecondArgClass_returnsTrue() {
        expect(FleetObjC._isClass(GrandchildClassUIViewController.self, kindOf: UIViewController.self)).to(beTrue())
        expect(FleetObjC._isClass(GrandchildClassUIViewController.self, kindOf: ChildClassUIViewController.self)).to(beTrue())
        expect(FleetObjC._isClass(ChildClassUIViewController.self, kindOf: UIViewController.self)).to(beTrue())
    }

    func test_isClassKindOf_whenFirstArgClassIsNotASubclassOfSecondArgClass_returnsFalse() {
        expect(FleetObjC._isClass(NSData.self, kindOf: UIViewController.self)).to(beFalse())
        expect(FleetObjC._isClass(ChildClassUIViewController.self, kindOf: GrandchildClassUIViewController.self)).to(beFalse())
    }
}
