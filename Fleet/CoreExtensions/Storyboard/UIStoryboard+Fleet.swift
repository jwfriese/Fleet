import Foundation
import UIKit
import ObjectiveC

private var storyboardInstanceBindingMap = [String : StoryboardInstanceBinding]()
private var storyboardBindingIdentifierAssociationKey: UInt8 = 0

extension UIStoryboard {
    var storyboardBindingIdentifier: String? {
        get {
            return objc_getAssociatedObject(self, &storyboardBindingIdentifierAssociationKey) as? String
        }
        set {
            objc_setAssociatedObject(self, &storyboardBindingIdentifierAssociationKey,
                                     newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
}

extension UIStoryboard {
    fileprivate func initializeStoryboardBindings() throws {
        let storyboardName = self.value(forKey: "name") as! String
        if storyboardBindingIdentifier == nil {
            storyboardBindingIdentifier = storyboardName + "_" + UUID().uuidString
        }

        if let storyboardBindingIdentifier = storyboardBindingIdentifier {
            if storyboardInstanceBindingMap[storyboardBindingIdentifier] == nil {
                let deserializer = StoryboardDeserializer()
                let storyboardReference = try deserializer.deserializeStoryboardWithName(storyboardName)
                storyboardInstanceBindingMap[storyboardBindingIdentifier] = StoryboardInstanceBinding(fromStoryboardName: storyboardName, storyboardReferenceMap: storyboardReference)
            }
        }
    }

    /**
        Binds the given view controller to the view controller reference associated with the
        given identifier. The bound view controller will then always be returned when the
        bound identifier is used to instantiate a view controller, even in segues.

        - Parameter viewController:     The view controller to bind
        - Parameter identifier:     The identifier whose reference should have the view controller
                                    bound to it

        - Throws: A `FLTStoryboardBindingError.InvalidViewControllerIdentifier` if there is no
            view controller reference on the storyboard with the given identifier.
    */
    public func bindViewController(_ viewController: UIViewController, toIdentifier identifier: String) throws {
        try initializeStoryboardBindings()
        if let storyboardBindingIdentifier = storyboardBindingIdentifier {
            if let storyboardInstanceBinding = storyboardInstanceBindingMap[storyboardBindingIdentifier] {
                try storyboardInstanceBinding.bindViewController(viewController, toIdentifier: identifier)
            }
        }
    }

    /**
        Binds the given view controller to the view controller reference associated with the
        given identifier on the external storyboard reference with the given name. The bound view
        controller will then always be returned when the bound identifier is used to instantiate a
        view controller, even in segues. Use this to bind view controllers to external storyboard
        references.

        - Parameter viewController:     The view controller to bind
        - Parameter identifier:     The identifier whose reference should have the view controller
            bound to it
        - Parameter referencedStoryboardName:     The name of the storyboard to which the external
            reference is associated

        - Throws: A `FLTStoryboardBindingError.InvalidExternalStoryboardReference` if there is no
            external storyboard view controller reference on the storyboard with the given identifier
            and given storyboard name.
    */
    public func bindViewController(_ viewController: UIViewController, toIdentifier identifier: String,forReferencedStoryboardWithName referencedStoryboardName: String) throws {
        try initializeStoryboardBindings()
        if let storyboardBindingIdentifier = storyboardBindingIdentifier {
            if let storyboardInstanceBinding = storyboardInstanceBindingMap[storyboardBindingIdentifier] {
                try storyboardInstanceBinding.bindViewController(viewController, toIdentifier: identifier,
                                                                 forReferencedStoryboardWithName:referencedStoryboardName)
            }
        }
    }

    /**
        Binds the given view controller to be the initial view controller instantiated from the
        external storyboard associated with the given storyboard name. The bound view controller
        will then always be returned when the external storyboard reference is used to instantiate a
        view controller, even in segues. Use this to bind view controllers to external storyboard
        references that instantiate the extenral storyboard's initial view controller.

        - Parameter viewController:     The view controller to bind
        - Parameter referencedStoryboardName:     The name of the storyboard to which the external
            reference is associated

        - Throws: A `FLTStoryboardBindingError.InvalidExternalStoryboardReference` if there is no
            external storyboard view controller reference on the storyboard with the given
            storyboard name.
    */
    public func bindViewController(_ viewController: UIViewController, asInitialViewControllerForReferencedStoryboardWithName referencedStoryboardName: String) throws {
        try initializeStoryboardBindings()
        if let storyboardBindingIdentifier = storyboardBindingIdentifier {
            if let storyboardInstanceBinding = storyboardInstanceBindingMap[storyboardBindingIdentifier] {
                try storyboardInstanceBinding.bindViewController(viewController, asInitialViewControllerForReferencedStoryboardWithName: referencedStoryboardName)
            }
        }
    }

    open override class func initialize() {
        struct Static {
            static var token = NSUUID().uuidString
        }
        
        DispatchQueue.once(token: Static.token) {
            swizzleViewControllerInstantiationMethod()
            swizzlePrivateStoryboardReferenceViewControllerInstantiationMethod()
        }
    }

    class func swizzleViewControllerInstantiationMethod() {
        let originalSelector = #selector(UIStoryboard.instantiateViewController(withIdentifier:))
        let swizzledSelector = #selector(UIStoryboard.fleet_instantiateViewControllerWithIdentifier(_:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_instantiateViewControllerWithIdentifier(_ identifier: String) -> UIViewController {
        if let storyboardBindingIdentifier = storyboardBindingIdentifier {
            if let storyboardInstanceBinding = storyboardInstanceBindingMap[storyboardBindingIdentifier] {
                if let boundInstance = storyboardInstanceBinding.viewControllerForIdentifier(identifier) {
                    return boundInstance
                }
            }
        }

        let viewController = fleet_instantiateViewControllerWithIdentifier(identifier)
        return viewController
    }

    class func swizzlePrivateStoryboardReferenceViewControllerInstantiationMethod() {
        let originalSelector = Selector("instantiateViewControllerReferencedByPlaceholderWithIdentifier:")
        let swizzledSelector = #selector(UIStoryboard.fleet_instantiateViewControllerReferencedByPlaceholderWithIdentifier(_:))

        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func fleet_instantiateViewControllerReferencedByPlaceholderWithIdentifier(_ identifier: String) -> UIViewController {
        if let storyboardBindingIdentifier = storyboardBindingIdentifier {
            if let storyboardInstanceBinding = storyboardInstanceBindingMap[storyboardBindingIdentifier] {
                if let boundInstance = storyboardInstanceBinding.viewControllerForIdentifier(identifier) {
                    return boundInstance
                }
            }
        }

        let viewController = self.fleet_instantiateViewControllerReferencedByPlaceholderWithIdentifier(identifier)
        return viewController
    }
}
