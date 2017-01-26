import UIKit
import ObjectiveC

extension Fleet {
    enum MockError: Error, CustomStringConvertible {
        case classCannotBeMocked

        var description: String {
            get {
                switch self {
                case .classCannotBeMocked:
                    return "Fleet only creates mocks for UIViewController subclasses"
                }
            }
        }
    }

    static func mockFor<T>(_ klass: T.Type) throws -> T where T: UIViewController {
        guard FleetObjC._isClass(klass, kindOf: UIViewController.self) else {
            throw MockError.classCannotBeMocked
        }

        let mock = FleetObjC._mock(for: klass)
        return mock as! T
    }
}
