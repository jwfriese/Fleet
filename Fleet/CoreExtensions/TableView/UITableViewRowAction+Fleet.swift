import UIKit
import ObjectiveC

private var handlerAssociatedKey: UInt = 0

fileprivate var didSwizzle = false

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

    override open class func initialize() {
        super.initialize()
        if !didSwizzle {
            swizzleInit()
            didSwizzle = true
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

    fileprivate class func swizzleInit() {
        let originalSelector = Selector(("_initWithStyle:title:handler:"))
        let swizzledSelector = #selector(UITableViewRowAction.fleet_init(withStyle:title:handler:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_init(withStyle style: UITableViewRowActionStyle, title: String?, handler: @escaping ((UITableViewRowAction, IndexPath) -> Swift.Void)) -> UITableViewRowAction {
        fleet_property_handler = handler
        return fleet_init(withStyle: style, title: title, handler: handler)
    }
}
