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

    override public class func initialize() {
        struct Static {
            static var token: dispatch_once_t = 0
        }

        dispatch_once(&Static.token) {
            swizzleHandlerSetter()
        }
    }

    private class func swizzleHandlerSetter() {
        let originalSelector = Selector("setHandler:")
        let swizzledSelector = #selector(UIAlertAction.fleet_setHandler(_:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_setHandler(handler: ((UIAlertAction) -> Void)?) {
        fleet_property_handler = handler
        fleet_setHandler(handler)
    }

    private var fleet_property_handler: ((UIAlertAction) -> Void)? {
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
