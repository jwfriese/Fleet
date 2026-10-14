import Foundation

@MainActor
class StoryboardDeserializer {
    /// Reads the compiled metadata for the storyboard with the given name.
    ///
    /// With an explicit `bundle`, only that bundle is consulted. Otherwise every loaded test bundle is
    /// searched: a single match is used, identical copies are accepted, and differing copies are
    /// reported as a conflict that an explicit bundle resolves.
    func deserializeStoryboard(withName name: String, in bundle: Bundle? = nil, searching candidates: [Bundle]? = nil) throws -> StoryboardReferenceMap {
        let relativePath = "/StoryboardInfo/\(name)/Info.plist"

        if let bundle = bundle {
            let path = bundle.bundlePath + relativePath
            guard FileManager.default.fileExists(atPath: path) else {
                let message = "Failed to build storyboard reference map for storyboard with name '\(name)': bundle '\(bundle.bundlePath)' has no StoryboardInfo/\(name)/Info.plist. Check that the bundle is the one whose test target runs Fleet's storyboard metadata script, and that the storyboard name is correct."
                throw FleetFailure.storyboard(.invalidSetup, action: "read storyboard metadata", target: "storyboard '\(name)'", message: message, reason: "Pass the bundle that holds the metadata to useBindingMetadata(forStoryboardNamed:in:).")
            }
            return try readReferenceMap(atPath: path, name: name)
        }

        let searched = candidates ?? Fleet.loadedTestBundles
        guard !searched.isEmpty else {
            let message = "Could not find test bundle to load storyboard with name '\(name)'"
            throw FleetFailure.storyboard(.invalidSetup, action: "read storyboard metadata", target: "storyboard '\(name)'", message: message, reason: "Run the tests from a hosted test bundle, or pass a bundle to useBindingMetadata(forStoryboardNamed:in:).")
        }

        let matches = searched.map { $0.bundlePath + relativePath }.filter { FileManager.default.fileExists(atPath: $0) }
        guard let firstMatch = matches.first else {
            let message = "Failed to build storyboard reference map for storyboard with name '\(name)'. Either this storyboard does not exist or Fleet is not set up for storyboard binding and mocking. Check the documentation to ensure that you have set up Fleet correctly to use its storyboard features."
            throw FleetFailure.storyboard(.invalidSetup, action: "read storyboard metadata", target: "storyboard '\(name)'", message: message, reason: "Add Fleet's storyboard metadata script to the test target and check the storyboard name.")
        }

        let reference = try readReferenceMap(atPath: firstMatch, name: name)
        for other in matches.dropFirst() {
            if try readReferenceMap(atPath: other, name: name) != reference {
                let message = "Storyboard '\(name)' has conflicting metadata in more than one test bundle: \(matches.joined(separator: ", ")). Call useBindingMetadata(forStoryboardNamed:in:) on the storyboard to choose the bundle."
                throw FleetFailure.storyboard(.invalidSetup, action: "read storyboard metadata", target: "storyboard '\(name)'", message: message, reason: "Choose the bundle with useBindingMetadata(forStoryboardNamed:in:).")
            }
        }
        return reference
    }

    private func readReferenceMap(atPath storyboardPath: String, name: String) throws -> StoryboardReferenceMap {
        guard let storyboardInfoDictionary = NSDictionary(contentsOfFile: storyboardPath) else {
            let message = "Failed to read storyboard metadata for storyboard with name '\(name)' at '\(storyboardPath)'. The file is not a valid property list; rebuild the test target to regenerate it."
            throw FleetFailure.storyboard(.invalidSetup, action: "read storyboard metadata", target: "storyboard '\(name)'", message: message, reason: "Rebuild the test target to regenerate the metadata.")
        }
        var reference = StoryboardReferenceMap()
        if let nibNameDictionary = storyboardInfoDictionary["UIViewControllerIdentifiersToNibNames"] as? [String : String] {
            reference.viewControllerIdentifiers = Array(nibNameDictionary.keys)
        }

        let externalReferencesKey = "UIViewControllerIdentifiersToExternalStoryboardReferences"
        guard let externalReferences = storyboardInfoDictionary[externalReferencesKey] as? [String : AnyObject] else {
            reference.viewControllerIdentifiers.sort()
            return reference
        }

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

        reference.viewControllerIdentifiers.sort()
        reference.externalReferences.sort { $0.connectedViewControllerIdentifier < $1.connectedViewControllerIdentifier }
        return reference
    }
}
