import UIKit
import ObjectiveC

extension Fleet {
    static func mockFor(_ klass: AnyClass) throws -> UIViewController {
        guard FleetObjC._isClass(klass, kindOf: UIViewController.self) else {
            let error = FleetError(message: "Fleet only creates mocks for UIViewController subclasses")
            throw error
        }

        let mock = FleetObjC._mock(for: klass)
        return mock as! UIViewController
    }
}
