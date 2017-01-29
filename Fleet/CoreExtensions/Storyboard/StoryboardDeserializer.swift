import Foundation

class StoryboardDeserializer {
    func deserializeStoryboard(withName name: String) throws -> StoryboardReferenceMap {
        guard let testBundle = Fleet.currentTestBundle else {
            let message = "Could not find test bundle to load storyboard with name \(name)"
            throw Fleet.StoryboardError.internalInconsistency(message)
        }

        let storyboardPath = testBundle.bundlePath + "/StoryboardInfo/\(name)/Info.plist"
        guard FileManager.default.fileExists(atPath: storyboardPath) else {
            let message = "Failed to build storyboard reference map for storyboard with name '\(name)'. Either this storyboard does not exist or Fleet is not set up for storyboard binding and mocking. Check the documentation to ensure that you have set up Fleet correctly to use its storyboard features."
            throw Fleet.StoryboardError.internalInconsistency(message)
        }

        var reference = StoryboardReferenceMap()
        guard let storyboardInfoDictionary = NSDictionary(contentsOfFile: storyboardPath) else { return reference }
        if let nibNameDictionary = storyboardInfoDictionary["UIViewControllerIdentifiersToNibNames"] as? [String : String] {
            reference.viewControllerIdentifiers = nibNameDictionary.map() { (key, value) in
                return key
            }
        }

        let externalReferencesKey = "UIViewControllerIdentifiersToExternalStoryboardReferences"
        guard let externalReferences = storyboardInfoDictionary[externalReferencesKey] as? [String : AnyObject] else { return reference }

        for identifier in externalReferences.keys {
            var newRef = ExternalReferenceDefinition()
            if let referenceDictionary = externalReferences[identifier] as? [String : String] {
                newRef.connectedViewControllerIdentifier = identifier
                if let externalStoryboardName = referenceDictionary["UIReferencedStoryboardName"] {
                    newRef.externalStoryboardName = externalStoryboardName
                }

                if let externalViewControllerIdentifier = referenceDictionary["UIReferencedControllerIdentifier"] {
                    newRef.externalViewControllerIdentifier = externalViewControllerIdentifier
                }
            }

            reference.externalReferences.append(newRef)
        }

        return reference
    }
}
