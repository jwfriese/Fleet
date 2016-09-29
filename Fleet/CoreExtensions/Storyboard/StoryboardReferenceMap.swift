import Foundation

struct ExternalReferenceDefinition {
    var connectedViewControllerIdentifier = ""
    var externalViewControllerIdentifier = ""
    var externalStoryboardName = ""
}

struct StoryboardReferenceMap {
    var viewControllerIdentifiers: [String] = []
    var externalReferences: [ExternalReferenceDefinition] = []

    func hasExternalReference(withIdentifier identifier: String) -> Bool {
        for externalReference in externalReferences {
            if identifier == externalReference.externalViewControllerIdentifier {
                return true
            }
        }

        return false
    }
}
