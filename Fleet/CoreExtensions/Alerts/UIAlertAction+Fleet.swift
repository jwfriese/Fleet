import UIKit
import ObjectiveC

private var handlerAssociatedKey: UInt = 0

@objc private class ObjectifiedBlock: NSObject {
    var block: ((UIAlertAction) -> Void)?

    init(block: ((UIAlertAction) -> Void)?) {
        self.block = block
    }
}

extension UIAlertAction {
    var handler: ((UIAlertAction) -> Void)? {
        get {
            return fleet_property_handler
        }
    }

    @objc class func swizzleHandlerSetter() {
        let originalSelector = Selector(("setHandler:"))
        let swizzledSelector = #selector(UIAlertAction.fleet_setHandler(_:))

        guard let originalMethod = class_getInstanceMethod(self, originalSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UIAlertAction.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }

        guard let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UIAlertAction.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func fleet_setHandler(_ handler: ((UIAlertAction) -> Void)?) {
        fleet_property_handler = handler
        fleet_setHandler(handler)
    }

    fileprivate var fleet_property_handler: ((UIAlertAction) -> Void)? {
        get {
            let block = objc_getAssociatedObject(self, &handlerAssociatedKey) as? ObjectifiedBlock
            return block?.block
        }

        set {
            let block = ObjectifiedBlock(block: newValue)
            objc_setAssociatedObject(self, &handlerAssociatedKey, block, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
}
