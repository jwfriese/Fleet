import XCTest
import Nimble
@testable import Fleet

#if os(iOS)
    @testable import FleetTestApp
#elseif os(tvOS)
    @testable import FleetTestApp_tvOS
#endif

@MainActor
class StoryboardDeserializerSpec: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
    }

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

    // MARK: Explicit and multi-bundle metadata

    private var temporaryDirectories: [URL] = []

    override func tearDown() async throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories = []
        try await super.tearDown()
    }

    private func makeBundle(storyboard name: String, identifiers: [String]?, malformed: Bool = false) -> Bundle {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FleetStoryboardTests-\(UUID().uuidString).xctest")
        temporaryDirectories.append(root)
        if let identifiers = identifiers {
            let directory = root.appendingPathComponent("StoryboardInfo/\(name)")
            try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent("Info.plist")
            if malformed {
                try! "not a plist".write(to: file, atomically: true, encoding: .utf8)
            } else {
                let nibNames = Dictionary(uniqueKeysWithValues: identifiers.map { ($0, "nib-\($0)") })
                (["UIViewControllerIdentifiersToNibNames": nibNames] as NSDictionary).write(to: file, atomically: true)
            }
        } else {
            try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return Bundle(path: root.path)!
    }

    func test_deserializingStoryboard_withExplicitBundle_readsOnlyThatBundle() {
        let bundle = makeBundle(storyboard: "Shared", identifiers: ["A"])
        let reference = try! StoryboardDeserializer().deserializeStoryboard(withName: "Shared", in: bundle)
        expect(reference.viewControllerIdentifiers).to(equal(["A"]))
    }

    func test_deserializingStoryboard_withExplicitBundleMissingMetadata_namesTheBundle() {
        let bundle = makeBundle(storyboard: "Shared", identifiers: nil)
        expect { _ = try StoryboardDeserializer().deserializeStoryboard(withName: "Shared", in: bundle) }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Failed to build storyboard reference map for storyboard with name 'Shared': bundle '\(bundle.bundlePath)' has no StoryboardInfo/Shared/Info.plist. Check that the bundle is the one whose test target runs Fleet's storyboard metadata script, and that the storyboard name is correct.", userInfo: nil, closure: nil)
        )
    }

    func test_deserializingStoryboard_withMalformedMetadata_raisesException() {
        let bundle = makeBundle(storyboard: "Shared", identifiers: ["A"], malformed: true)
        expect { _ = try StoryboardDeserializer().deserializeStoryboard(withName: "Shared", in: bundle) }.to(
            raiseException(named: "Fleet.StoryboardError")
        )
    }

    func test_deserializingStoryboard_acrossTestBundles_usesTheBundleThatHasTheStoryboard() {
        let without = makeBundle(storyboard: "Other", identifiers: ["X"])
        let with = makeBundle(storyboard: "Shared", identifiers: ["A", "B"])
        let reference = try! StoryboardDeserializer().deserializeStoryboard(withName: "Shared", searching: [without, with])
        expect(reference.viewControllerIdentifiers).to(equal(["A", "B"]))
    }

    func test_deserializingStoryboard_acrossTestBundles_acceptsIdenticalCopies() {
        let first = makeBundle(storyboard: "Shared", identifiers: ["A", "B"])
        let second = makeBundle(storyboard: "Shared", identifiers: ["B", "A"])
        let reference = try! StoryboardDeserializer().deserializeStoryboard(withName: "Shared", searching: [first, second])
        expect(reference.viewControllerIdentifiers).to(equal(["A", "B"]))
    }

    func test_deserializingStoryboard_acrossTestBundles_rejectsConflictingCopies() {
        let first = makeBundle(storyboard: "Shared", identifiers: ["A"])
        let second = makeBundle(storyboard: "Shared", identifiers: ["B"])
        expect { _ = try StoryboardDeserializer().deserializeStoryboard(withName: "Shared", searching: [first, second]) }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Storyboard 'Shared' has conflicting metadata in more than one test bundle: \(first.bundlePath)/StoryboardInfo/Shared/Info.plist, \(second.bundlePath)/StoryboardInfo/Shared/Info.plist. Call useBindingMetadata(forStoryboardNamed:in:) on the storyboard to choose the bundle.", userInfo: nil, closure: nil)
        )
    }

    func test_deserializingStoryboard_withExplicitBundle_resolvesConflictingCopies() {
        let first = makeBundle(storyboard: "Shared", identifiers: ["A"])
        let second = makeBundle(storyboard: "Shared", identifiers: ["B"])
        expect(try! StoryboardDeserializer().deserializeStoryboard(withName: "Shared", in: first).viewControllerIdentifiers).to(equal(["A"]))
        expect(try! StoryboardDeserializer().deserializeStoryboard(withName: "Shared", in: second).viewControllerIdentifiers).to(equal(["B"]))
    }

    func test_deserializingStoryboard_withNoTestBundles_raisesException() {
        expect { _ = try StoryboardDeserializer().deserializeStoryboard(withName: "Shared", searching: []) }.to(
            raiseException(named: "Fleet.StoryboardError", reason: "Could not find test bundle to load storyboard with name 'Shared'", userInfo: nil, closure: nil)
        )
    }
}
