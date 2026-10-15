import XCTest
import Fleet
import Nimble

#if os(iOS)
    @testable import FleetTestApp
#elseif os(tvOS)
    @testable import FleetTestApp_tvOS
#endif

@MainActor
fileprivate class TestTarget: NSObject {
    var didCallAction = false

    var senders: [Any?] = []

    @objc func action() {
        didCallAction = true
    }

    @objc func actionWithSender(_ sender: Any?) {
        didCallAction = true
        senders.append(sender)
    }
}

@MainActor
private class ResponderChainViewController: UIViewController {
    var actionCount = 0

    override var canBecomeFirstResponder: Bool { true }

    @objc func chainAction(_ sender: Any?) {
        actionCount += 1
    }
}

@MainActor
class UIBarButtonItem_FleetSpec: XCTestCase {
    var subject: UIBarButtonItem!
    fileprivate var testTarget: TestTarget!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        let viewController = UIViewController()
        let navigationController = UINavigationController(rootViewController: viewController)

        testTarget = TestTarget()
        subject = UIBarButtonItem(title: "turtles", style: .plain, target: testTarget, action: #selector(TestTarget.action))
        navigationController.navigationItem.rightBarButtonItem = subject
        Fleet.setAsAppWindowRoot(navigationController)
    }

    func test_tap_performsButtonAction() {
        subject.tap()
        expect(self.testTarget.didCallAction).to(beTrue())
    }

    func test_tap_whenNotEnabled_raisesException() {
        subject.isEnabled = false
        expect { self.subject.tap() }.to(
            raiseException(named: "Fleet.BarButtonItemError", reason: "Cannot tap UIBarButtonItem: Control is not enabled.", userInfo: nil, closure: nil)
        )
    }

    func test_tap_whenNoTarget_raisesException() {
        subject.target = nil
        // A nil target dispatches through the responder chain, so use an action no responder implements.
        subject.action = Selector(("fleetNoResponderImplementsThis:"))
        expect { self.subject.tap() }.to(
            raiseException(named: "Fleet.BarButtonItemError", reason: "Attempted to tap UIBarButtonItem (title='turtles') with no associated target, and no responder in the responder chain handles the action.", userInfo: nil, closure: nil)
        )
    }

    func test_tap_whenTargetIsNil_dispatchesActionThroughResponderChain() {
        let controller = ResponderChainViewController()
        Fleet.setAsAppWindowRoot(controller)
        expect(controller.becomeFirstResponder()).to(beTrue())
        defer { _ = controller.resignFirstResponder() }

        let item = UIBarButtonItem(title: "chain", style: .plain, target: nil, action: #selector(ResponderChainViewController.chainAction(_:)))
        item.tap()

        expect(controller.actionCount).to(equal(1))
    }

    func test_tap_whenTargetDoesNotRespondToAction_raisesExceptionWithoutCrashing() {
        subject.action = #selector(ResponderChainViewController.chainAction(_:))
        expect { self.subject.tap() }.to(
            raiseException(named: "Fleet.BarButtonItemError", reason: "Attempted to tap UIBarButtonItem (title='turtles') whose target does not respond to the action.", userInfo: nil, closure: nil)
        )
    }

    func test_tap_passesItemAsSenderExactlyOnce() {
        subject.action = #selector(TestTarget.actionWithSender(_:))
        subject.tap()
        expect(self.testTarget.senders.count).to(equal(1))
        expect(self.testTarget.senders.first.flatMap { $0 as? UIBarButtonItem }).to(beIdenticalTo(subject))
    }

    func test_tap_invokesPrimaryActionExactlyOnce() {
        var count = 0
        let item = UIBarButtonItem(primaryAction: UIAction(title: "primary") { _ in count += 1 })
        item.tap()
        expect(count).to(equal(1))
    }

    func test_tap_whenPrimaryActionItemIsDisabled_doesNotInvokeAction() {
        var count = 0
        let item = UIBarButtonItem(primaryAction: UIAction(title: "primary") { _ in count += 1 })
        item.isEnabled = false
        expect { item.tap() }.to(
            raiseException(named: "Fleet.BarButtonItemError", reason: "Cannot tap UIBarButtonItem: Control is not enabled.", userInfo: nil, closure: nil)
        )
        expect(count).to(equal(0))
    }

    #if os(iOS)
    func test_tap_whenItemOnlyPresentsMenu_raisesException() {
        var count = 0
        let item = UIBarButtonItem(title: "menu", menu: UIMenu(children: [UIAction(title: "x") { _ in count += 1 }]))
        expect { item.tap() }.to(
            raiseException(named: "Fleet.BarButtonItemError", reason: "Cannot tap UIBarButtonItem: Item presents a menu, which tap() cannot open. Invoke the menu element's handler directly.", userInfo: nil, closure: nil)
        )
        expect(count).to(equal(0))
    }

    func test_tap_whenItemHasPrimaryActionAndMenu_invokesPrimaryActionExactlyOnce() {
        var primaryCount = 0
        var menuCount = 0
        let item = UIBarButtonItem(
            primaryAction: UIAction(title: "primary") { _ in primaryCount += 1 },
            menu: UIMenu(children: [UIAction(title: "x") { _ in menuCount += 1 }])
        )
        item.tap()
        expect(primaryCount).to(equal(1))
        expect(menuCount).to(equal(0))
    }
    #endif

    func test_tap_whenNoAction_raisesException() {
        subject.action = nil
        expect { self.subject.tap() }.to(
            raiseException(named: "Fleet.BarButtonItemError", reason: "Attempted to tap UIBarButtonItem (title='turtles') with no associated action.", userInfo: nil, closure: nil)
        )
    }
}
