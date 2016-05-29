import UIKit
import ObjectiveC

private var storyboardInstanceBindingMap = [String : StoryboardInstanceBinding]()
private var storyboardBindingIdentifierAssociationKey: UInt8 = 0

extension UIStoryboard {
    var storyboardBindingIdentifier: String? {
        get {
            return objc_getAssociatedObject(self, &storyboardBindingIdentifierAssociationKey) as? String
        }
        set(newValue) {
            objc_setAssociatedObject(self, &storyboardBindingIdentifierAssociationKey,
                                     newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
}

extension UIStoryboard {
    public func bindViewController(viewController: UIViewController, toIdentifier identifier: String) throws {
        if let storyboardBindingIdentifier = storyboardBindingIdentifier {
            if let storyboardInstanceBinding = storyboardInstanceBindingMap[storyboardBindingIdentifier] {
                try storyboardInstanceBinding.bindViewController(viewController, toIdentifier: identifier)
            }
        }
    }
    
    public func bindViewController(viewController: UIViewController, toIdentifier identifier: String, forReferencedStoryboardWithName referencedStoryboardName: String) throws {
        
        if let storyboardBindingIdentifier = storyboardBindingIdentifier {
            if let storyboardInstanceBinding = storyboardInstanceBindingMap[storyboardBindingIdentifier] {
                try storyboardInstanceBinding.bindViewController(viewController, toIdentifier: identifier,
                                                                 forReferencedStoryboardWithName: referencedStoryboardName)
            }
        }
    }
    
    public func bindViewController(viewController: UIViewController, asInitialViewControllerForReferencedStoryboardWithName referencedStoryboardName: String) throws {
        
        if let storyboardBindingIdentifier = storyboardBindingIdentifier {
            if let storyboardInstanceBinding = storyboardInstanceBindingMap[storyboardBindingIdentifier] {
                try storyboardInstanceBinding.bindViewController(viewController, asInitialViewControllerForReferencedStoryboardWithName: referencedStoryboardName)
            }
        }
    }
    
    public override class func initialize() {
        struct Static {
            static var token: dispatch_once_t = 0
        }
        
        dispatch_once(&Static.token) {
            swizzleInit()
            swizzleViewControllerInstantiationMethod()
            swizzlePrivateStoryboardReferenceViewControllerInstantiationMethod()
        }
    }
    
    class func swizzleInit() {
        let originalSelector = Selector("initWithBundle:storyboardFileName:identifierToNibNameMap:identifierToExternalStoryboardReferenceMap:designatedEntryPointIdentifier:")
        let swizzledSelector = #selector(UIStoryboard.fleet_initWithBundle(_:storyboardFileName:identifierToNibNameMap:identifierToExternalStoryboardReferenceMap:designatedEntryPointIdentifier:))
        
        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
        
        let didAddMethod = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        
        if didAddMethod {
            class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    func fleet_initWithBundle(bundle: NSBundle?,
                              storyboardFileName: String,
                              identifierToNibNameMap: [String : String]?,
                              identifierToExternalStoryboardReferenceMap: AnyObject?,
                              designatedEntryPointIdentifier: AnyObject) -> UIStoryboard {
        let instance = self.fleet_initWithBundle(bundle, storyboardFileName: storyboardFileName, identifierToNibNameMap: identifierToNibNameMap, identifierToExternalStoryboardReferenceMap: identifierToExternalStoryboardReferenceMap, designatedEntryPointIdentifier: designatedEntryPointIdentifier)
        
        let storyboardName = self.valueForKey("name") as! String
        storyboardBindingIdentifier = storyboardName + "_" + NSUUID().UUIDString
        storyboardInstanceBindingMap[storyboardBindingIdentifier!] = StoryboardInstanceBinding(fromStoryboardName: storyboardName, externalStoryboardReferenceMap: identifierToExternalStoryboardReferenceMap as? [String : AnyObject], nibNameMap: identifierToNibNameMap)
        
        return instance
    }

    class func swizzleViewControllerInstantiationMethod() {
        let originalSelector = #selector(UIStoryboard.instantiateViewControllerWithIdentifier(_:))
        let swizzledSelector = #selector(UIStoryboard.fleet_instantiateViewControllerWithIdentifier(_:))
        
        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
        
        let didAddMethod = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        
        if didAddMethod {
            class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    func fleet_instantiateViewControllerWithIdentifier(identifier: String) -> UIViewController {
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
        
        let didAddMethod = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        
        if didAddMethod {
            class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    func fleet_instantiateViewControllerReferencedByPlaceholderWithIdentifier(identifier: String) -> UIViewController {
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
