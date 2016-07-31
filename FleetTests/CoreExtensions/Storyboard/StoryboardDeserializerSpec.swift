import XCTest
import Nimble
@testable import Fleet
@testable import FleetTestApp

class StoryboardDeserializerSpec: XCTestCase {
    func test_deserializingStoryboard_whenStoryboardWithNameInBundleCannotBeFound_throwsError() {
        let deserializer = StoryboardDeserializer()
        expect {
            try deserializer.deserializeStoryboardWithName("garbage", fromBundle: NSBundle.mainBundle())
        }.to(
            throwError()
        )
    }
    
    func test_deserializingStoryboard_whenStoryboardExists_deserializesIntoStoryboardReferenceMap() {
        let deserializer = StoryboardDeserializer()
        let bundle = NSBundle(forClass: AnimalListViewController.self)
        let reference = try! deserializer.deserializeStoryboardWithName("TurtlesAndFriendsStoryboard",
                                                                        fromBundle:bundle)
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
