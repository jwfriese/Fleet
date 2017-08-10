import UIKit
import ObjectiveC

private var handlerAssociatedKey: UInt = 0

@objc private class ObjectifiedBlock: NSObject {
    var block: ((UITableViewRowAction, IndexPath) -> Void)?

    init(block: ((UITableViewRowAction, IndexPath) -> Void)?) {
        self.block = block
    }
}

extension UITableViewRowAction {
    var handler: ((UITableViewRowAction, IndexPath) -> Void)? {
        get {
            return fleet_property_handler
        }
    }

    fileprivate var fleet_property_handler: ((UITableViewRowAction, IndexPath) -> Void)? {
        get {
            let block = objc_getAssociatedObject(self, &handlerAssociatedKey) as? ObjectifiedBlock
            return block?.block
        }

        set {
            let block = ObjectifiedBlock(block: newValue)
            objc_setAssociatedObject(self, &handlerAssociatedKey, block, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }

    @objc class func swizzleInit() {
        let originalSelector = Selector(("_initWithStyle:title:handler:"))
        let swizzledSelector = #selector(UITableViewRowAction.fleet_init(withStyle:title:handler:))

        guard let originalMethod = class_getInstanceMethod(self, originalSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UITableViewRowAction.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }
        guard let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(UITableViewRowAction.self) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func fleet_init(withStyle style: UITableViewRowActionStyle, title: String?, handler: @escaping ((UITableViewRowAction, IndexPath) -> Swift.Void)) -> UITableViewRowAction {
        fleet_property_handler = handler
        return fleet_init(withStyle: style, title: title, handler: handler)
    }
}
