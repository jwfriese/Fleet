import XCTest
import Nimble

/// Proves the shared fixture hands the next scenario the UI state the previous one borrowed.
@MainActor
class HostedUIFixtureSpec: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
    }

    private func mutateEverythingATestMight(_ fixture: HostedUIFixture) throws -> (field: UIView, window: UIWindow) {
        // A real text field with a local input view, as FleetSpec does, so no system keyboard starts.
        // tvOS has no text-input responder session to restore here, so a plain view stands in.
        #if os(iOS)
        let field = UITextField(frame: CGRect(x: 10, y: 10, width: 100, height: 40))
        field.inputView = UIView()
        try fixture.embed(field)
        _ = field.becomeFirstResponder()
        #else
        let field = UIView(frame: CGRect(x: 10, y: 10, width: 100, height: 40))
        try fixture.embed(field)
        #endif
        let window = fixture.makeKeyWindow(root: UIViewController())
        return (field, window)
    }

    func test_restore_returnsKeyWindowRootEmbeddedViewsAndFirstResponderToTheirOriginalState() async throws {
        let original = UIApplication.shared.keyWindow
        let originalRoot = original?.rootViewController
        let originalSubviews = originalRoot?.view.subviews ?? []
        let fixture = HostedUIFixture()

        let (field, window) = try mutateEverythingATestMight(fixture)
        expect(UIApplication.shared.keyWindow).to(beIdenticalTo(window))
        await fixture.restore()

        expect(fixture.isRestored).to(beTrue())
        expect(field.isFirstResponder).to(beFalse())
        expect(field.superview).to(beNil())
        expect(window.isHidden).to(beTrue())
        expect(UIApplication.shared.keyWindow).to(beIdenticalTo(original))
        expect(original?.rootViewController).to(beIdenticalTo(originalRoot))
        expect(originalRoot?.view.subviews ?? []).to(equal(originalSubviews))
    }

    func test_restore_dismissesPresentationsAndRestoresARootThatTheTestReplaced() async throws {
        let original = UIApplication.shared.keyWindow
        let originalRoot = original?.rootViewController
        let fixture = HostedUIFixture()

        let replacement = UIViewController()
        Fleet_setRoot(replacement)
        replacement.present(UIViewController(), animated: false)
        expect(replacement.presentedViewController).toNot(beNil())
        await fixture.restore()

        expect(fixture.isRestored).to(beTrue())
        expect(replacement.presentedViewController).to(beNil())
        expect(original?.rootViewController).to(beIdenticalTo(originalRoot))
    }

    private func waitUntil(_ description: String, timeout: TimeInterval = 5, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline { XCTFail("Timed out after \(timeout)s waiting until \(description)"); return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func test_restore_dismissesTheWholeNestedPresentationChain() async throws {
        let root = UIApplication.shared.keyWindow?.rootViewController
        let baselineTop = root.flatMap { r -> UIViewController? in
            var top = r
            while let next = top.presentedViewController { top = next }
            return top
        }
        let fixture = HostedUIFixture()

        let first = UIViewController()
        let second = UIViewController()
        baselineTop?.present(first, animated: false)
        try await waitUntil("first is presented") { first.presentingViewController != nil && first.view.window != nil }
        first.present(second, animated: false)
        try await waitUntil("second is presented") { first.presentedViewController === second }
        await fixture.restore()

        expect(baselineTop?.presentedViewController).to(beNil())
        expect(first.presentedViewController).to(beNil())
        expect(fixture.isRestored).to(beTrue())
    }

    func test_restore_preservesPresentationsThatBelongedToTheBorrowedBaseline() async throws {
        let root = try XCTUnwrap(UIApplication.shared.keyWindow?.rootViewController)
        let baselineModal = UIViewController()
        root.present(baselineModal, animated: false)
        try await waitUntil("baseline modal is presented") { baselineModal.view.window != nil }

        let fixture = HostedUIFixture()
        let scenarioModal = UIViewController()
        baselineModal.present(scenarioModal, animated: false)
        try await waitUntil("scenario modal is presented") { baselineModal.presentedViewController === scenarioModal }
        await fixture.restore()

        expect(root.presentedViewController).to(beIdenticalTo(baselineModal))
        expect(baselineModal.presentedViewController).to(beNil())
        expect(fixture.isRestored).to(beTrue())

        // Return the application to the state other tests expect.
        root.dismiss(animated: false)
        let deadline = Date().addingTimeInterval(5)
        while root.presentedViewController != nil && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        expect(root.presentedViewController).to(beNil())
    }

    func test_restore_removesEveryViewEmbeddedThroughTheFixture() async throws {
        let root = try XCTUnwrap(UIApplication.shared.keyWindow?.rootViewController)
        let baseline = root.view.subviews
        let fixture = HostedUIFixture()
        try fixture.embed(UIView())
        try fixture.embed(UIView())
        expect(root.view.subviews.count).to(equal(baseline.count + 2))
        await fixture.restore()
        expect(root.view.subviews).to(equal(baseline))
    }

    private func Fleet_setRoot(_ controller: UIViewController) {
        UIApplication.shared.keyWindow?.rootViewController = controller
        UIApplication.shared.keyWindow?.layoutIfNeeded()
    }

    // Alphabetical order runs this before the successor test below; the successor asserts the
    // application is clean after the throwing path restored it.
    func test_a_restore_onAThrowingPath_stillCleansUp() async {
        struct Boom: Error {}
        let fixture = HostedUIFixture()
        do {
            _ = try mutateEverythingATestMight(fixture)
            throw Boom()
        } catch {
            await fixture.restore()
        }
        expect(fixture.isRestored).to(beTrue())
    }

    func test_b_successorScenario_startsFromTheOriginalApplicationState() async throws {
        let fixture = HostedUIFixture()
        expect(fixture.isRestored).to(beTrue())
        expect(UIApplication.shared.keyWindow?.rootViewController?.presentedViewController).to(beNil())
        expect(UIApplication.shared.keyWindow?.rootViewController?.view.subviews.contains { $0.frame == CGRect(x: 10, y: 10, width: 100, height: 40) } ?? false).to(beFalse())
        await fixture.restore()
    }
}
