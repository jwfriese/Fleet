import UIKit

internal final class StoryboardInstanceBinding {
    private var binding = [String : UIViewController]()
    
    private var storyboardName: String
    private var storyboardReferenceMap: StoryboardReferenceMap?
    
    init(fromStoryboardName storyboardName: String, storyboardReferenceMap: StoryboardReferenceMap?) {
        self.storyboardName = storyboardName
        self.storyboardReferenceMap = storyboardReferenceMap
    }
    
    func viewControllerForIdentifier(identifier: String) -> UIViewController? {
        return binding[identifier]
    }
    
    func bindViewController(viewController: UIViewController, toIdentifier identifier: String) throws {
        if let storyboardReferenceMap = storyboardReferenceMap {
            if !storyboardReferenceMap.viewControllerIdentifiers.contains(identifier) {
                var message = ""
                if storyboardReferenceMap.hasExternalReferenceForIdentifier(identifier) {
                    message = "Could not find identifier \(identifier) on storyboard with name \(storyboardName), but found this identifier on an external storyboard reference. Use UIStoryboard.bindViewController(_:toIdentifier:forReferencedStoryboardWithName:) to bind to external references"
                } else {
                    message = "Could not find identifier \(identifier) on storyboard with name \(storyboardName)"
                }
                
                throw FLTStoryboardBindingError.InvalidViewControllerIdentifier(message)
            }
        } else {
            throw FLTStoryboardBindingError.InternalInconsistency("Failed to build storyboard reference map. Check the documentation to ensure that you have set up Fleet correctly for storyboard testing")
        }
        
        binding[identifier] = viewController
    }
    
    func bindViewController(viewController: UIViewController, toIdentifier identifier: String, forReferencedStoryboardWithName name: String) throws {
        
        var referenceExists = false
        if let storyboardReferenceMap = storyboardReferenceMap {
            for externalReference in storyboardReferenceMap.externalReferences {
                if externalReference.externalViewControllerIdentifier == identifier &&
                    externalReference.externalStoryboardName == name {
                    binding[externalReference.connectedViewControllerIdentifier] = viewController
                    referenceExists = true
                }
            }
        }
        
        if !referenceExists {
            throw FLTStoryboardBindingError.InvalidExternalStoryboardReference("Could not find identifier \(identifier) (external storyboard reference: \(name)) on storyboard \(storyboardName)")
        }
    }
    
    func bindViewController(viewController: UIViewController, asInitialViewControllerForReferencedStoryboardWithName name: String) throws {
        var referenceExists = false
        if let storyboardReferenceMap = storyboardReferenceMap {
            for externalReference in storyboardReferenceMap.externalReferences {
                if externalReference.externalStoryboardName == name {
                    if externalReference.externalViewControllerIdentifier == "" {
                        binding[externalReference.connectedViewControllerIdentifier] = viewController
                        referenceExists = true
                    }
                }
            }
        }
        
        if !referenceExists {
            throw FLTStoryboardBindingError.InvalidExternalStoryboardReference("Could not find reference to an external storyboard with name \(name) on storyboard \(storyboardName)")
        }
    }
    
    func clear() {
        binding.removeAll()
    }
}
