import XCTest
import UIKit
import Nimble

@testable import Fleet

fileprivate class MockForSpecViewController: UIViewController {
    var didCallViewDidLoad: Bool = false
    var didCallViewWillAppear: Bool = false
    var didCallViewDidAppear: Bool = false
    var didCallViewWillDisappear: Bool = false
    var didCallViewDidDisappear: Bool = false

    fileprivate override func viewDidLoad() {
        didCallViewDidLoad = true
    }

    fileprivate override func viewWillAppear(_ animated: Bool) {
        didCallViewWillAppear = true
    }

    fileprivate override func viewDidAppear(_ animated: Bool) {
        didCallViewDidAppear = true
    }

    fileprivate override func viewWillDisappear(_ animated: Bool) {
        didCallViewWillDisappear = true
    }

    fileprivate override func viewDidDisappear(_ animated: Bool) {
        didCallViewDidDisappear = true
    }
}

class MockForSpec: XCTestCase {
    func test_mockFor_whenGivenAViewControllerClass_returnsMockThatIsASubclassOfTheGivenClass() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)
        expect(mock).toNot(beNil())
        expect(mock).to(beAKindOf(MockForSpecViewController.self))
    }

    func test_mockFor_whenTheMockCallsViewDidLoadDirectly_itDoesNotExecuteItsMockedClassViewDidLoadMethod() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)

        let uiKitMock: UIViewController = mock

        uiKitMock.viewDidLoad()
        expect(mock.didCallViewDidLoad).to(beFalse())
    }

    func test_mockFor_whenTheMockCallsViewDidLoadImplicitly_itDoesNotExecuteItsMockedClassViewDidLoadMethod() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)

        let _ = mock.view
        expect(mock.didCallViewDidLoad).to(beFalse())
    }

    func test_mockFor_whenTheMockIsPresentedInAWindow_itDoesNotExecuteItsMockedClassViewDidLoadMethod() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)

        Fleet.setAsAppWindowRoot(mock)
        expect(mock.didCallViewDidLoad).to(beFalse())
    }

    func test_mockFor_whenTheMockCallsViewWillAppear_itDoesNotExecuteItsMockedClassViewWillAppearMethod() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)

        let uiKitMock: UIViewController = mock

        uiKitMock.viewWillAppear(false)
        expect(mock.didCallViewWillAppear).to(beFalse())
    }

    func test_mockFor_whenTheMockCallsViewDidAppear_itDoesNotExecuteItsMockedClassViewDidAppearMethod() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)

        let uiKitMock: UIViewController = mock

        uiKitMock.viewDidAppear(false)
        expect(mock.didCallViewDidAppear).to(beFalse())
    }

    func test_mockFor_whenTheMockCallsViewWillDisappear_itDoesNotExecuteItsMockedClassViewWillDisappearMethod() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)

        let uiKitMock: UIViewController = mock

        uiKitMock.viewWillDisappear(false)
        expect(mock.didCallViewWillDisappear).to(beFalse())
    }

    func test_mockFor_whenTheMockCallsViewDidDisappear_itDoesNotExecuteItsMockedClassViewDidDisappearMethod() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)

        let uiKitMock: UIViewController = mock

        uiKitMock.viewDidDisappear(false)
        expect(mock.didCallViewDidDisappear).to(beFalse())
    }

    func test_mockFor_whenAMockIsCreated_itDoesNotAffectOtherInstancesOfTheMockedType() {
        let _ = try! Fleet.mockFor(MockForSpecViewController.self)
        let anotherInstance: UIViewController = MockForSpecViewController()

        guard let castedMock = anotherInstance as? MockForSpecViewController else {
            fail("Failed to create other instance correctly")
            return
        }

        anotherInstance.viewDidLoad()
        expect(castedMock.didCallViewDidLoad).to(beTrue())

        anotherInstance.viewWillAppear(false)
        expect(castedMock.didCallViewWillAppear).to(beTrue())

        anotherInstance.viewDidAppear(false)
        expect(castedMock.didCallViewDidAppear).to(beTrue())

        anotherInstance.viewWillDisappear(false)
        expect(castedMock.didCallViewWillDisappear).to(beTrue())

        anotherInstance.viewDidDisappear(false)
        expect(castedMock.didCallViewDidDisappear).to(beTrue())
    }

    func test_mockFor_allowsMockingOfUIViewController() {
        do {
            let _ = try Fleet.mockFor(UIViewController.self)

        } catch {
            fail("Expected not to throw an error")
        }
    }
}
