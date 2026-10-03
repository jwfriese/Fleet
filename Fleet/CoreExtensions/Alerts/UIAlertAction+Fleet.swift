import UIKit
import ObjectiveC

@MainActor private var handlerAssociatedKey: UInt = 0

@MainActor
@objc private class ObjectifiedBlock: NSObject {
    var block: ((UIAlertAction) -> Void)?

    init(block: ((UIAlertAction) -> Void)?) {
        self.block = block
    }
}

@MainActor
extension UIAlertAction {
    var handler: ((UIAlertAction) -> Void)? {
        get {
            return fleet_property_handler
        }
    }

    @objc nonisolated class func swizzleHandlerSetter() {
        Fleet.swizzle(
            originalSelector: Selector(("setHandler:")),
            swizzledSelector: #selector(UIAlertAction.fleet_setHandler(_:)),
            forClass: self
        )
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
