extension Fleet {
    class func swizzle(originalSelector: Selector, swizzledSelector: Selector, forClass klass: AnyClass) {
        guard let originalMethod = class_getInstanceMethod(klass, originalSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(klass) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }
        guard let swizzledMethod = class_getInstanceMethod(klass, swizzledSelector) else {
            FleetError(Fleet.InternalError.unrecoverable(details: "Failed to swizzle on class \(klass) - Original selector: \(originalSelector); New selector: \(swizzledSelector)")).raise()
            return
        }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}
