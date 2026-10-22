import UIKit
import ObjectiveC

@MainActor private var handlerAssociatedKey: UInt = 0

/// Written only from the single-threaded `+load` installer (and, for tests, on the main actor).
private nonisolated(unsafe) var handlerCaptureHookInstalled = false

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
        // A missing retained private selector is recorded as a capability state instead of
        // raising from `+load`; strict alert helpers then fail with a typed error at action time.
        guard class_getInstanceMethod(self, Selector(("setHandler:"))) != nil else {
            handlerCaptureHookInstalled = false
            return
        }
        handlerCaptureHookInstalled = true
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

    /// Whether the private `setHandler:` hook was installed at load time.
    static var isHandlerCaptureAvailable: Bool { handlerCaptureHookInstalled }

    /// What Fleet actually observed about this action's handler. See `Fleet.AlertHandlerCapture`.
    var handlerCapture: Fleet.AlertHandlerCapture {
        guard handlerCaptureHookInstalled else { return .unavailable }
        guard let block = objc_getAssociatedObject(self, &handlerAssociatedKey) as? ObjectifiedBlock else {
            return .unobserved
        }
        return block.block == nil ? .observedNil : .observedHandler
    }

    /// Test seam: forgets capture evidence, as if UIKit had not routed the handler through the hook.
    func fleet_discardCaptureEvidence() {
        objc_setAssociatedObject(self, &handlerAssociatedKey, nil, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
    }

    /// Test seam: simulates an unavailable capture hook. Returns the previous value.
    @discardableResult
    static func fleet_setCaptureHookInstalled(_ installed: Bool) -> Bool {
        let previous = handlerCaptureHookInstalled
        handlerCaptureHookInstalled = installed
        return previous
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
