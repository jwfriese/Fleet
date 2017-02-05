import UIKit

internal final class StoryboardInstanceBinding {
    fileprivate var binding = [String : UIViewController]()

    fileprivate var storyboardName: String
    fileprivate var storyboardReferenceMap: StoryboardReferenceMap?

    init(fromStoryboardName storyboardName: String, storyboardReferenceMap: StoryboardReferenceMap?) {
        self.storyboardName = storyboardName
        self.storyboardReferenceMap = storyboardReferenceMap
    }

    func viewController(forIdentifier identifier: String) -> UIViewController? {
        return binding[identifier]
    }

    func bind(viewController: UIViewController, toIdentifier identifier: String) throws {
        if let storyboardReferenceMap = storyboardReferenceMap {
            if !storyboardReferenceMap.viewControllerIdentifiers.contains(identifier) {
                var message = ""
                if storyboardReferenceMap.hasExternalReference(withIdentifier: identifier) {
                    message = "Could not find identifier \(identifier) on storyboard with name \(storyboardName), but found this identifier on an external storyboard reference. Use UIStoryboard.bind(viewController:toIdentifier:forReferencedStoryboardWithName:) to bind to external references"
                } else {
                    message = "Could not find identifier \(identifier) on storyboard with name \(storyboardName)"
                }

                FleetError(Fleet.StoryboardError.invalidViewControllerIdentifier(message)).raise()
            }
        } else {
            FleetError(Fleet.StoryboardError.internalInconsistency("Failed to build storyboard reference map. Check the documentation to ensure that you have set up Fleet correctly for storyboard testing")).raise()
        }

        binding[identifier] = viewController
    }

    func bind(viewController: UIViewController, toIdentifier identifier: String, forReferencedStoryboardWithName name: String) throws {

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
            FleetError(Fleet.StoryboardError.invalidExternalStoryboardReference("Could not find identifier \(identifier) (external storyboard reference: \(name)) on storyboard \(storyboardName)")).raise()
        }
    }

    func bind(viewController: UIViewController, asInitialViewControllerForReferencedStoryboardWithName name: String) throws {
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
            FleetError(Fleet.StoryboardError.invalidExternalStoryboardReference("Could not find reference to an external storyboard with name \(name) on storyboard \(storyboardName)")).raise()
        }
    }

    func clear() {
        binding.removeAll()
    }
}
