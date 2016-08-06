import XCTest
import Nimble
@testable import Fleet
@testable import FleetTestApp

class StoryboardDeserializerSpec: XCTestCase {
    func test_deserializingStoryboard_whenStoryboardWithNameInBundleCannotBeFound_throwsError() {
        let deserializer = StoryboardDeserializer()
        var threwError = false
        do {
            try deserializer.deserializeStoryboardWithName("garbage")
        } catch FLTStoryboardBindingError.InternalInconsistency(let message) {
            threwError = true
            expect(message).to(equal("Failed to build storyboard reference map for storyboard with name garbage. Either this storyboard does not exist or Fleet is not set up for storyboard binding. Check the documentation to ensure that you have set up Fleet correctly for storyboard testing"))
        } catch { }

        if !threwError {
            fail("Expected to throw InternalInconsistency error")
        }
    }

    func test_deserializingStoryboard_whenStoryboardExists_deserializesIntoStoryboardReferenceMap() {
        let deserializer = StoryboardDeserializer()
        let reference = try! deserializer.deserializeStoryboardWithName("TurtlesAndFriendsStoryboard")
        expect(reference.externalReferences.count).to(equal(3))
        if reference.externalReferences.count > 3 {
            expect(reference.externalReferences[0].connectedViewControllerIdentifier).to(equal("UIViewController-gcW-ev-w5z"))
            expect(reference.externalReferences[1].connectedViewControllerIdentifier).to(equal("UIViewController-fVV-aN-iXJ"))
            expect(reference.externalReferences[2].connectedViewControllerIdentifier).to(equal("UIViewController-s4q-fa-MbE"))

            expect(reference.externalReferences[0].externalViewControllerIdentifier).to(equal("CrabViewController"))
            expect(reference.externalReferences[1].externalViewControllerIdentifier).to(equal(""))
            expect(reference.externalReferences[2].externalViewControllerIdentifier).to(equal("CrabViewController"))

            expect(reference.externalReferences[0].externalStoryboardName).to(equal("CrabStoryboard"))
            expect(reference.externalReferences[1].externalStoryboardName).to(equal("PuppyStoryboard"))
            expect(reference.externalReferences[2].externalStoryboardName).to(equal("CrabStoryboard"))
        }
    }
}
