import UIKit
import ObjectiveC

extension Fleet {
    enum MockError: Error, CustomStringConvertible {
        case missingUIViewControllerSuperClass
        case unsupportedClassForMocking

        var description: String {
            get {
                switch self {
                case .missingUIViewControllerSuperClass:
                    return "Fleet only creates mocks for UIViewController subclasses"
                case .unsupportedClassForMocking:
                    return "Fleet cannot mock instances of UICollectionViewController or its subclasses"
                }
            }
        }
    }

    static func mockFor<T>(_ klass: T.Type) throws -> T where T: UIViewController {
        guard FleetObjC._isClass(klass, kindOf: UIViewController.self) else {
            throw MockError.missingUIViewControllerSuperClass
        }

        if FleetObjC._isClass(klass, kindOf: UICollectionViewController.self) {
            throw MockError.unsupportedClassForMocking
        }

        let mock = FleetObjC._mock(for: klass)
        return mock as! T
    }
}
