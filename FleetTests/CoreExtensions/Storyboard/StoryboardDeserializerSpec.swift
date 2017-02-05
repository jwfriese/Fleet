import XCTest
import Nimble
@testable import Fleet
@testable import FleetTestApp

class StoryboardDeserializerSpec: XCTestCase {
    func test_deserializingStoryboard_whenStoryboardWithNameInBundleCannotBeFound_raisesException() {
        let deserializer = StoryboardDeserializer()
        expect { _ = try deserializer.deserializeStoryboard(withName: "garbage") }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Failed to build storyboard reference map for storyboard with name 'garbage'. Either this storyboard does not exist or Fleet is not set up for storyboard binding and mocking. Check the documentation to ensure that you have set up Fleet correctly to use its storyboard features.", userInfo: nil, closure: nil)
        )
    }

    func test_deserializingStoryboard_whenStoryboardExists_deserializesIntoStoryboardReferenceMap() {
        let deserializer = StoryboardDeserializer()
        let reference = try! deserializer.deserializeStoryboard(withName: "TurtlesAndFriendsStoryboard")
        expect(reference.externalReferences.count).to(equal(5))

        expect(reference.externalReferences).to(containElementSatisfying({ reference in
            let identifiersEqual = reference.connectedViewControllerIdentifier == "UIViewController-s4q-fa-MbE"
            let externalIdentifiersEqual = reference.externalViewControllerIdentifier == "CrabViewController"
            let storyboardNamesEqual = reference.externalStoryboardName == "CrabStoryboard"
            return identifiersEqual && externalIdentifiersEqual && storyboardNamesEqual
        }))

        expect(reference.externalReferences).to(containElementSatisfying({ reference in
            let identifiersEqual = reference.connectedViewControllerIdentifier == "UIViewController-fVV-aN-iXJ"
            let externalIdentifiersEqual = reference.externalViewControllerIdentifier == ""
            let storyboardNamesEqual = reference.externalStoryboardName == "PuppyStoryboard"
            return identifiersEqual && externalIdentifiersEqual && storyboardNamesEqual
        }))

        expect(reference.externalReferences).to(containElementSatisfying({ reference in
            let identifiersEqual = reference.connectedViewControllerIdentifier == "UIViewController-pfk-wd-JTs"
            let externalIdentifiersEqual = reference.externalViewControllerIdentifier == ""
            let storyboardNamesEqual = reference.externalStoryboardName == "KittensStoryboard"
            return identifiersEqual && externalIdentifiersEqual && storyboardNamesEqual
        }))

        expect(reference.externalReferences).to(containElementSatisfying({ reference in
            let identifiersEqual = reference.connectedViewControllerIdentifier == "UIViewController-gcW-ev-w5z"
            let externalIdentifiersEqual = reference.externalViewControllerIdentifier == "CrabViewController"
            let storyboardNamesEqual = reference.externalStoryboardName == "CrabStoryboard"
            return identifiersEqual && externalIdentifiersEqual && storyboardNamesEqual
        }))
    }
}
