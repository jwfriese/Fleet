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
                throw FLTStoryboardBindingError.InvalidViewControllerIdentifier
            }
        } else {
            throw FLTStoryboardBindingError.InvalidViewControllerIdentifier
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
            throw FLTStoryboardBindingError.InvalidExternalStoryboardReference
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
            throw FLTStoryboardBindingError.InvalidExternalStoryboardReference
        }
    }
    
    func clear() {
        binding.removeAll()
    }
}
