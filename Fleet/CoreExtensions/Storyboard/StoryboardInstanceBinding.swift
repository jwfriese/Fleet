import UIKit

internal final class StoryboardInstanceBinding {
    private var binding = [String : UIViewController]()
    
    private var storyboardName: String
    private var externalStoryboardReferenceMap: [String : AnyObject]?
    
    init(fromStoryboardName storyboardName: String, externalStoryboardReferenceMap: [String : AnyObject]?) {
        self.storyboardName = storyboardName
        self.externalStoryboardReferenceMap = externalStoryboardReferenceMap
    }
    
    func viewControllerForIdentifier(identifier: String) -> UIViewController? {
        return binding[identifier]
    }
//    
//    func boundInitialViewControllerForStoryboardWithName(storyboardName: String) -> UIViewController? {
//        return binding[storyboardName]
//    }
    
    func bindViewController(viewController: UIViewController, toIdentifier identifier: String) -> Bool {
        binding[identifier] = viewController
        return true
    }
    
    func bindViewController(viewController: UIViewController, toIdentifier identifier: String, forReferencedStoryboardWithName name: String) -> Bool {
        
        if let externalStoryboardReferenceMap = externalStoryboardReferenceMap {
            for (nextIdentifier, reference) in externalStoryboardReferenceMap {
                if let reference = reference as? [String : AnyObject] {
                    if let viewControllerIdentifier = reference["UIReferencedControllerIdentifier"] as? String {
                        if let referencedStoryboardName = reference["UIReferencedStoryboardName"] as? String {
                            if viewControllerIdentifier == identifier && referencedStoryboardName == name {
                                binding[nextIdentifier] = viewController
                            }
                        }
                    }
                }
            }
        }
        
        return true
    }
    
    func bindViewController(viewController: UIViewController, asInitialViewControllerForReferencedStoryboardWithName name: String) -> Bool {
        if let externalStoryboardReferenceMap = externalStoryboardReferenceMap {
            for (nextIdentifier, reference) in externalStoryboardReferenceMap {
                if let reference = reference as? [String : AnyObject] {
                    if let referencedStoryboardName = reference["UIReferencedStoryboardName"] as? String {
                        if referencedStoryboardName == name {
                            let specificViewControllerIdentifier = reference["UIReferencedControllerIdentifier"] as? String
                            if specificViewControllerIdentifier == nil {
                                binding[nextIdentifier] = viewController
                            }
                        }
                    }
                }
            }
        }
        
        return true
    }
    
    func clear() {
        binding.removeAll()
    }
    
    private func combinedIdentifierFromViewControllerIdentifier(identifier: String, storyboardName: String) -> String {
        return identifier + ":" + storyboardName
    }
}
