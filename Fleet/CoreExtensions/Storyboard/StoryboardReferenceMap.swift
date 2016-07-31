import Foundation

struct ExternalReferenceDefinition {
    var connectedViewControllerIdentifier = ""
    var externalViewControllerIdentifier = ""
    var externalStoryboardName = ""
}

struct StoryboardReferenceMap {
    var viewControllerIdentifiers: [String] = []
    var externalReferences: [ExternalReferenceDefinition] = []
}
