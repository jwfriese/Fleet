import UIKit

@MainActor
internal final class StoryboardInstanceBinding {
    /// Registrations per identifier, oldest first; the last one is visible. Each remembers the
    /// context that made it (`nil` for registrations made outside any context), so ending a
    /// context removes only its own registrations and reveals whatever they overrode.
    private struct Registration {
        let owner: ObjectIdentifier?
        let viewController: UIViewController
    }
    private var registrations = [String : [Registration]]()

    fileprivate var storyboardName: String
    fileprivate var storyboardReferenceMap: StoryboardReferenceMap?

    init(fromStoryboardName storyboardName: String, storyboardReferenceMap: StoryboardReferenceMap?) {
        self.storyboardName = storyboardName
        self.storyboardReferenceMap = storyboardReferenceMap
    }

    func viewController(forIdentifier identifier: String) -> UIViewController? {
        return registrations[identifier]?.last?.viewController
    }

    var isEmpty: Bool { registrations.isEmpty }

    private func register(_ viewController: UIViewController, forIdentifier identifier: String, owner: FleetTestContext?) {
        let ownerID = owner.map(ObjectIdentifier.init)
        // A later registration by the same owner replaces that owner's earlier one.
        var stack = (registrations[identifier] ?? []).filter { $0.owner != ownerID }
        stack.append(Registration(owner: ownerID, viewController: viewController))
        registrations[identifier] = stack
        owner?.adoptStoryboardBinding(self)
    }

    /// Removes registrations made by `owner`, releasing their controllers and revealing any
    /// registration they overrode. Other owners' registrations are untouched.
    func removeRegistrations(ownedBy owner: ObjectIdentifier) {
        for (identifier, stack) in registrations {
            let remaining = stack.filter { $0.owner != owner }
            registrations[identifier] = remaining.isEmpty ? nil : remaining
        }
    }

    func bind(viewController: UIViewController, toIdentifier identifier: String, owner: FleetTestContext?) throws {
        if let storyboardReferenceMap = storyboardReferenceMap {
            if !storyboardReferenceMap.viewControllerIdentifiers.contains(identifier) {
                var message = ""
                if storyboardReferenceMap.hasExternalReference(withIdentifier: identifier) {
                    message = "Could not find identifier '\(identifier)' on storyboard with name '\(storyboardName)', but found this identifier on an external storyboard reference. Use UIStoryboard.bind(viewController:toIdentifier:forReferencedStoryboardWithName:) to bind to external references"
                } else {
                    message = "Could not find identifier '\(identifier)' on storyboard with name '\(storyboardName)'"
                }

                throw FleetFailure.storyboard(.invalidInput, action: "bind view controller", target: "storyboard '\(storyboardName)' identifier '\(identifier)'", message: message, reason: "Use an identifier that exists on the storyboard.")
            }
        } else {
            throw FleetFailure.storyboard(.invalidSetup, action: "bind view controller", target: "storyboard '\(storyboardName)'", message: "Failed to build storyboard reference map. Check the documentation to ensure that you have set up Fleet correctly for storyboard testing", reason: "Set up Fleet's storyboard metadata script for the test target.")
        }

        register(viewController, forIdentifier: identifier, owner: owner)
    }

    func bind(viewController: UIViewController, toIdentifier identifier: String, forReferencedStoryboardWithName name: String, owner: FleetTestContext?) throws {

        var referenceExists = false
        if let storyboardReferenceMap = storyboardReferenceMap {
            for externalReference in storyboardReferenceMap.externalReferences {
                if externalReference.externalViewControllerIdentifier == identifier &&
                    externalReference.externalStoryboardName == name {
                    register(viewController, forIdentifier: externalReference.connectedViewControllerIdentifier, owner: owner)
                    referenceExists = true
                }
            }
        }

        if !referenceExists {
            throw FleetFailure.storyboard(.invalidInput, action: "bind view controller", target: "storyboard '\(storyboardName)' external reference '\(name)'", message: "Could not find identifier '\(identifier)' (external storyboard reference: '\(name)') on storyboard '\(storyboardName)'", reason: "Use an identifier and reference name that exist on the storyboard.")
        }
    }

    func bind(viewController: UIViewController, asInitialViewControllerForReferencedStoryboardWithName name: String, owner: FleetTestContext?) throws {
        var referenceExists = false
        if let storyboardReferenceMap = storyboardReferenceMap {
            for externalReference in storyboardReferenceMap.externalReferences {
                if externalReference.externalStoryboardName == name {
                    if externalReference.externalViewControllerIdentifier == "" {
                        register(viewController, forIdentifier: externalReference.connectedViewControllerIdentifier, owner: owner)
                        referenceExists = true
                    }
                }
            }
        }

        if !referenceExists {
            throw FleetFailure.storyboard(.invalidInput, action: "bind initial view controller", target: "storyboard '\(storyboardName)' external reference '\(name)'", message: "Could not find reference to an external storyboard with name '\(name)' on storyboard '\(storyboardName)'", reason: "Use the name of an external storyboard reference on this storyboard.")
        }
    }

    func clear() {
        registrations.removeAll()
    }
}
