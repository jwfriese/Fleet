import Foundation

class StoryboardDeserializer {
    func deserializeStoryboardWithName(name: String) throws -> StoryboardReferenceMap {
        guard let testBundle = Fleet.currentTestBundle else {
            let userInfo = ["error" : "Could not find test bundle to load"]
            throw NSError(domain: "Fleet Storyboard Read Error", code: NSFileNoSuchFileError, userInfo: userInfo)
        }
        
        let storyboardPath = testBundle.bundlePath + "/StoryboardInfo/\(name)/Info.plist"
        if !NSFileManager.defaultManager().fileExistsAtPath(storyboardPath) {
            let userInfo = ["error" : "Could not load storyboard at \(storyboardPath)"]
            throw NSError(domain: "Fleet Storyboard Read Error", code: NSFileNoSuchFileError, userInfo: userInfo)
        }
        
        var reference = StoryboardReferenceMap()
        
        let storyboardInfoDictionary = NSDictionary(contentsOfFile: storyboardPath)
        if let storyboardInfoDictionary = storyboardInfoDictionary {
            if let nibNameDictionary = storyboardInfoDictionary["UIViewControllerIdentifiersToNibNames"] as? [String : String] {
                reference.viewControllerIdentifiers = nibNameDictionary.map() { (key, value) in
                    return key
                }
            }
            
            let externalReferencesKey = "UIViewControllerIdentifiersToExternalStoryboardReferences"
            let externalReferences = storyboardInfoDictionary[externalReferencesKey]
            if let externalReferences = externalReferences as? [String : AnyObject] {
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
            }
        }
        
        return reference
    }
}
