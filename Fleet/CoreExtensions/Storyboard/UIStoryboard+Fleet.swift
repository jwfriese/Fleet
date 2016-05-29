import UIKit

private var storyboardInstanceBinding = StoryboardInstanceBinding()
private var externalStoryboardReferenceMap: [String : AnyObject]?

extension UIStoryboard {
    public func bindViewController(viewController: UIViewController, toIdentifier identifier: String) {
        storyboardInstanceBinding.bindViewController(viewController, toIdentifier: identifier, forStoryboardWithName: self.valueForKey("name") as! String)
    }
    
    public func bindViewController(viewController: UIViewController, toIdentifier identifier: String, fromStoryboardWithName storyboardName: String) {
        storyboardInstanceBinding.bindViewController(viewController, toIdentifier: identifier, forStoryboardWithName: storyboardName)
    }
    
    public override class func initialize() {
        struct Static {
            static var token: dispatch_once_t = 0
        }
        
        if self !== UIStoryboard.self {
            return
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
                              identifierToNibNameMap: AnyObject,
                              identifierToExternalStoryboardReferenceMap: AnyObject?,
                              designatedEntryPointIdentifier:AnyObject) -> UIStoryboard {
        let instance = self.fleet_initWithBundle(bundle, storyboardFileName: storyboardFileName, identifierToNibNameMap: identifierToNibNameMap, identifierToExternalStoryboardReferenceMap: identifierToExternalStoryboardReferenceMap, designatedEntryPointIdentifier: designatedEntryPointIdentifier)
        
        storyboardInstanceBinding.clear()
        externalStoryboardReferenceMap = identifierToExternalStoryboardReferenceMap as? [String : AnyObject]
        
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
        if let boundInstance = storyboardInstanceBinding.viewControllerForIdentifier(identifier, fromStoryboardWithName: self.valueForKey("name") as! String) {
            return boundInstance
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
        
        if let mapping = externalStoryboardReferenceMap?[identifier] as? [String : AnyObject] {
            if let viewControllerIdentifier = mapping["UIReferencedControllerIdentifier"] as? String {
                if let storyboardName = mapping["UIReferencedStoryboardName"] as? String {
                    if let boundInstance = storyboardInstanceBinding.viewControllerForIdentifier(viewControllerIdentifier, fromStoryboardWithName: storyboardName) {
                        return boundInstance
                    }
                }
            }
        }
        
        let viewController = self.fleet_instantiateViewControllerReferencedByPlaceholderWithIdentifier(identifier)
        return viewController
    }
}
