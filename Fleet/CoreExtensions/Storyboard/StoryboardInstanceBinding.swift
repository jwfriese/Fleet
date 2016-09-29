import UIKit

internal final class StoryboardInstanceBinding {
    fileprivate var binding = [String : UIViewController]()

    fileprivate var storyboardName: String
    fileprivate var storyboardReferenceMap: StoryboardReferenceMap?

    init(fromStoryboardName storyboardName: String, storyboardReferenceMap: StoryboardReferenceMap?) {
        self.storyboardName = storyboardName
        self.storyboardReferenceMap = storyboardReferenceMap
    }

    func viewControllerForIdentifier(_ identifier: String) -> UIViewController? {
        return binding[identifier]
    }

    func bindViewController(_ viewController: UIViewController, toIdentifier identifier: String) throws {
        if let storyboardReferenceMap = storyboardReferenceMap {
            if !storyboardReferenceMap.viewControllerIdentifiers.contains(identifier) {
                var message = ""
                if storyboardReferenceMap.hasExternalReferenceForIdentifier(identifier) {
                    message = "Could not find identifier \(identifier) on storyboard with name \(storyboardName), but found this identifier on an external storyboard reference. Use UIStoryboard.bindViewController(_:toIdentifier:forReferencedStoryboardWithName:) to bind to external references"
                } else {
                    message = "Could not find identifier \(identifier) on storyboard with name \(storyboardName)"
                }

                throw FLTStoryboardBindingError.invalidViewControllerIdentifier(message)
            }
        } else {
            throw FLTStoryboardBindingError.internalInconsistency("Failed to build storyboard reference map. Check the documentation to ensure that you have set up Fleet correctly for storyboard testing")
        }

        binding[identifier] = viewController
    }

    func bindViewController(_ viewController: UIViewController, toIdentifier identifier: String, forReferencedStoryboardWithName name: String) throws {

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
            throw FLTStoryboardBindingError.invalidExternalStoryboardReference("Could not find identifier \(identifier) (external storyboard reference: \(name)) on storyboard \(storyboardName)")
        }
    }

    func bindViewController(_ viewController: UIViewController, asInitialViewControllerForReferencedStoryboardWithName name: String) throws {
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
            throw FLTStoryboardBindingError.invalidExternalStoryboardReference("Could not find reference to an external storyboard with name \(name) on storyboard \(storyboardName)")
        }
    }

    func clear() {
        binding.removeAll()
    }
}
