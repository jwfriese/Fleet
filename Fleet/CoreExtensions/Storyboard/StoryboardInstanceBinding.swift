import UIKit

internal final class StoryboardInstanceBinding {
    private var binding = [String : UIViewController]()
    
    func viewControllerForIdentifier(identifier: String, fromStoryboardWithName storyboardName: String) -> UIViewController? {
        let combinedIdentifier = combinedIdentifierFromViewControllerIdentifier(identifier, storyboardName: storyboardName)
        return binding[combinedIdentifier]
    }
    
    func bindViewController(viewController: UIViewController, toIdentifier identifier: String, forStoryboardWithName storyboardName: String) {
        let combinedIdentifier = combinedIdentifierFromViewControllerIdentifier(identifier, storyboardName: storyboardName)
        binding[combinedIdentifier] = viewController
    }
    
    func clear() {
        binding.removeAll()
    }
    
    private func combinedIdentifierFromViewControllerIdentifier(identifier: String, storyboardName: String) -> String {
        return identifier + ":" + storyboardName
        
    }
}
