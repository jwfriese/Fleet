import XCTest
import UIKit
import Fleet
import Nimble

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
        let castedMock = mock as? MockForSpecViewController
        expect(castedMock).toNot(beNil())
    }

    func test_mockFor_whenTheMockCallsViewDidLoadDirectly_itDoesNotExecuteItsMockedClassViewDidLoadMethod() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)
        guard let castedMock = mock as? MockForSpecViewController else {
            fail("Failed to subclass correctly")
            return
        }

        mock.viewDidLoad()
        expect(castedMock.didCallViewDidLoad).to(beFalse())
    }

    func test_mockFor_whenTheMockCallsViewDidLoadImplicitly_itDoesNotExecuteItsMockedClassViewDidLoadMethod() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)
        guard let castedMock = mock as? MockForSpecViewController else {
            fail("Failed to subclass correctly")
            return
        }

        let _ = castedMock.view
        expect(castedMock.didCallViewDidLoad).to(beFalse())
    }

    func test_mockFor_whenTheMockIsPresentedInAWindow_itDoesNotExecuteItsMockedClassViewDidLoadMethod() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)
        guard let castedMock = mock as? MockForSpecViewController else {
            fail("Failed to subclass correctly")
            return
        }

        Fleet.setApplicationWindowRootViewController(mock)
        expect(castedMock.didCallViewDidLoad).to(beFalse())
    }

    func test_mockFor_whenTheMockCallsViewWillAppear_itDoesNotExecuteItsMockedClassViewWillAppearMethod() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)
        guard let castedMock = mock as? MockForSpecViewController else {
            fail("Failed to subclass correctly")
            return
        }

        mock.viewWillAppear(false)
        expect(castedMock.didCallViewWillAppear).to(beFalse())
    }

    func test_mockFor_whenTheMockCallsViewDidAppear_itDoesNotExecuteItsMockedClassViewDidAppearMethod() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)
        guard let castedMock = mock as? MockForSpecViewController else {
            fail("Failed to subclass correctly")
            return
        }

        mock.viewDidAppear(false)
        expect(castedMock.didCallViewDidAppear).to(beFalse())
    }

    func test_mockFor_whenTheMockCallsViewWillDisappear_itDoesNotExecuteItsMockedClassViewWillDisappearMethod() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)
        guard let castedMock = mock as? MockForSpecViewController else {
            fail("Failed to subclass correctly")
            return
        }

        mock.viewWillDisappear(false)
        expect(castedMock.didCallViewWillDisappear).to(beFalse())
    }

    func test_mockFor_whenTheMockCallsViewDidDisappear_itDoesNotExecuteItsMockedClassViewDidDisappearMethod() {
        let mock = try! Fleet.mockFor(MockForSpecViewController.self)
        guard let castedMock = mock as? MockForSpecViewController else {
            fail("Failed to subclass correctly")
            return
        }

        mock.viewDidDisappear(false)
        expect(castedMock.didCallViewDidDisappear).to(beFalse())
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

    func test_mockFor_whenGivenAClassThatIsNotASubclassOfUIViewController_throwsError() {
        var didThrowError = false
        do {
            let _ = try Fleet.mockFor(NSData.self)

        } catch let error {
            guard let fleetError = error as? FleetError else {
                fail("Expected thrown error to be of type FleetError")
                return
            }

            expect(String(describing: fleetError)).to(equal("Fleet error: Fleet only creates mocks for UIViewController subclasses"))
            didThrowError = true
        }

        expect(didThrowError).to(beTrue())
    }
}
