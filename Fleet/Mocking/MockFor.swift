import UIKit
import ObjectiveC
#if SWIFT_PACKAGE
import FleetRuntime
#endif

extension Fleet {
    enum MockError: Error, CustomStringConvertible {
        case missingUIViewControllerSuperClass

        var description: String {
            get {
                switch self {
                case .missingUIViewControllerSuperClass:
                    return "Fleet only creates mocks for UIViewController subclasses"
                }
            }
        }
    }

    @MainActor
    static func mockFor<T>(_ klass: T.Type) throws -> T where T: UIViewController {
        guard FleetObjC._isClass(klass, kindOf: UIViewController.self) else {
            throw MockError.missingUIViewControllerSuperClass
        }

        let mock = FleetObjC._mock(for: klass)
        return mock as! T
    }
}
