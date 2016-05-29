import UIKit

internal final class StoryboardInstanceBinding {
    private var binding = [String : UIViewController]()
    
    private var storyboardName: String
    private var externalStoryboardReferenceMap: [String : AnyObject]?
    private var nibNameMap: [String : String]?
    
    init(fromStoryboardName storyboardName: String, externalStoryboardReferenceMap: [String : AnyObject]?,
                            nibNameMap: [String : String]?) {
        self.storyboardName = storyboardName
        self.externalStoryboardReferenceMap = externalStoryboardReferenceMap
        self.nibNameMap = nibNameMap
    }
    
    func viewControllerForIdentifier(identifier: String) -> UIViewController? {
        return binding[identifier]
    }
    
    func bindViewController(viewController: UIViewController, toIdentifier identifier: String) throws {
        if nibNameMap?[identifier] == nil {
            throw FLTStoryboardBindingError.InvalidViewControllerIdentifier
        }
        
        binding[identifier] = viewController
    }
    
    func bindViewController(viewController: UIViewController, toIdentifier identifier: String, forReferencedStoryboardWithName name: String) throws {
        
        var referenceExists = false
        if let externalStoryboardReferenceMap = externalStoryboardReferenceMap {
            for (nextIdentifier, reference) in externalStoryboardReferenceMap {
                if let reference = reference as? [String : AnyObject] {
                    if let viewControllerIdentifier = reference["UIReferencedControllerIdentifier"] as? String {
                        if let referencedStoryboardName = reference["UIReferencedStoryboardName"] as? String {
                            if viewControllerIdentifier == identifier && referencedStoryboardName == name {
                                binding[nextIdentifier] = viewController
                                referenceExists = true
                            }
                        }
                    }
                }
            }
        }
        
        if !referenceExists {
            throw FLTStoryboardBindingError.InvalidExternalStoryboardReference
        }
    }
    
    func bindViewController(viewController: UIViewController, asInitialViewControllerForReferencedStoryboardWithName name: String) throws {
        
        var referenceExists = false
        if let externalStoryboardReferenceMap = externalStoryboardReferenceMap {
            for (nextIdentifier, reference) in externalStoryboardReferenceMap {
                if let reference = reference as? [String : AnyObject] {
                    if let referencedStoryboardName = reference["UIReferencedStoryboardName"] as? String {
                        if referencedStoryboardName == name {
                            let specificViewControllerIdentifier = reference["UIReferencedControllerIdentifier"] as? String
                            if specificViewControllerIdentifier == nil {
                                binding[nextIdentifier] = viewController
                                referenceExists = true
                            }
                        }
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
