import XCTest
import Nimble

@testable import Fleet

@MainActor
class UIToolbar_FleetSpec: XCTestCase {
    var rootViewController: TestViewController!
    var navigationController: UINavigationController!

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        rootViewController = TestViewController()
        navigationController = Fleet.setInAppWindowRootNavigation(rootViewController)

        let items = [
            UIBarButtonItem(
                title: "title",
                style: UIBarButtonItem.Style.plain,
                target: rootViewController,
                action: #selector(TestViewController.setFlag)
            )
        ]

        navigationController.toolbar.items = items
    }

    class TestViewController: UIViewController {
        var flag = false

        @objc func setFlag() {
            flag = true
        }
    }

    func test_tapButtonWithTitle_itemWithTitleExists_firesTheAction() {
        expect(self.rootViewController.flag).to(beFalse())

        navigationController.toolbar.tapItem(withTitle: "title")

        expect(self.rootViewController.flag).to(beTrue())
    }

    func test_tapButtonWithTitle_itemWithTitleDoesNotExist_throwsAnError() {
        expect(self.rootViewController.flag).to(beFalse())

        expect { self.navigationController.toolbar.tapItem(withTitle: "does not exist") }.to(
            raiseException(
                named: "Fleet.ToolbarError",
                reason: "No item with title 'does not exist' found in toolbar.",
                userInfo: nil,
                closure: nil
            )
        )

        expect(self.rootViewController.flag).to(beFalse())
    }

    func test_tapButtonWithTitle_duplicateTitles_throwsAnErrorAndTapsNothing() {
        let other = TestViewController()
        navigationController.toolbar.items = [
            UIBarButtonItem(title: "dup", style: .plain, target: rootViewController, action: #selector(TestViewController.setFlag)),
            UIBarButtonItem(title: "dup", style: .plain, target: other, action: #selector(TestViewController.setFlag)),
        ]

        expect { self.navigationController.toolbar.tapItem(withTitle: "dup") }.to(
            raiseException(
                named: "Fleet.ToolbarError",
                reason: "2 items with title 'dup' found in toolbar; Fleet will not guess which to tap.",
                userInfo: nil,
                closure: nil
            )
        )

        expect(self.rootViewController.flag).to(beFalse())
        expect(other.flag).to(beFalse())
    }
}
